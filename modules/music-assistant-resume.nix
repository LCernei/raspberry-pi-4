# Resume playback after a reboot or a Music Assistant restart. Music Assistant
# keeps its queues across restarts but never resumes them (checked in 2.10.13).
#
# - music-assistant-resume-record (every minute): saves which queues are playing.
# - music-assistant-resume (each time Music Assistant or Sendspin starts): resumes those
#   queues once their players are available again, so music that was stopped
#   stays stopped.
#
# Needs a long-lived Music Assistant token in
# /var/lib/secrets/music-assistant.token (root, 0600); without it, neither unit
# runs. Long-lived tokens expire after a year.
{ pkgs, ... }:

let
  tokenFile = "/var/lib/secrets/music-assistant.token";
  stateDir = "/var/lib/music-assistant-resume";

  script = pkgs.writeShellApplication {
    name = "music-assistant-resume";
    runtimeInputs = with pkgs; [
      curl
      jq
      util-linux # flock
    ];
    text = ''
      state="${stateDir}/playing.json"
      token="$(<"$CREDENTIALS_DIRECTORY/token")"

      api() {
        curl -fsS --max-time 15 \
          -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
          -d "$1" http://127.0.0.1:8095/api
      }

      record() {
        # The resume step holds the lock while it waits: do not overwrite the
        # saved state with the idle state right after a restart.
        exec 9>"${stateDir}/lock"
        flock -n 9 || exit 0
        local playing
        # Music Assistant down or starting: keep the last saved state. A queue
        # whose player is unavailable (e.g. the Pebble is off USB) keeps its
        # saved entry, so it resumes when the player returns.
        playing="$(api '{"command":"player_queues/all","args":{}}' 2>/dev/null |
          jq -c --argjson prev "$(cat "$state" 2>/dev/null || echo '[]')" '
            [.[] | select(.state == "playing"
              or (.available == false and (.queue_id | IN($prev[])))) | .queue_id]
          ')" || exit 0
        if [[ "$playing" != "$(cat "$state" 2>/dev/null)" ]]; then
          echo "playing queues: $playing"
          printf '%s\n' "$playing" >"$state.tmp"
          mv "$state.tmp" "$state"
        fi
      }

      resume() {
        exec 9>"${stateDir}/lock"
        flock 9
        [[ -s "$state" ]] || exit 0
        local queues queue_id deadline queue
        mapfile -t queues < <(jq -r '.[]' "$state")
        [[ ''${#queues[@]} -gt 0 ]] || exit 0
        # Wait for Music Assistant and the players (the Pebble may come back late),
        # resume, and retry until the queue is seen playing.
        deadline=$((SECONDS + 1800))
        for queue_id in "''${queues[@]}"; do
          while :; do
            queue="$(api "$(jq -nc --arg q "$queue_id" \
              '{command: "player_queues/get", args: {queue_id: $q}}')" 2>/dev/null)" ||
              queue='{}'
            if [[ "$(jq -r '.state // ""' <<<"$queue")" == playing ]]; then
              echo "queue $queue_id ($(jq -r '.display_name' <<<"$queue")) is playing"
              break
            fi
            if ((SECONDS > deadline)); then
              echo "queue $queue_id did not resume within 30 min, giving up"
              break
            fi
            if [[ "$(jq -r '.available // false' <<<"$queue")" == true ]]; then
              echo "resuming queue $queue_id ($(jq -r '.display_name' <<<"$queue"))"
              api "$(jq -nc --arg q "$queue_id" \
                '{command: "player_queues/resume", args: {queue_id: $q}}')" >/dev/null ||
                echo "resume of $queue_id failed, retrying"
              sleep 30
            else
              sleep 10
            fi
          done
        done
      }

      case "''${1:-}" in
      record) record ;;
      resume) resume ;;
      *)
        echo "usage: music-assistant-resume record|resume" >&2
        exit 2
        ;;
      esac
    '';
  };

  common = {
    unitConfig.ConditionPathExists = tokenFile;
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      StateDirectory = "music-assistant-resume";
      LoadCredential = "token:${tokenFile}";
    };
  };
in
{
  systemd.services.music-assistant-resume = common // {
    description = "Resume Music Assistant queues that were playing before a restart";
    # Also when Sendspin starts: Music Assistant does not resume a player that
    # comes back (checked: the Pebble power-cycled, playback stayed stopped).
    wantedBy = [
      "docker-music-assistant.service"
      "sendspin.service"
    ];
    after = [
      "docker-music-assistant.service"
      "sendspin.service"
    ];
    partOf = [ "docker-music-assistant.service" ];
    serviceConfig = common.serviceConfig // {
      ExecStart = "${script}/bin/music-assistant-resume resume";
      TimeoutStartSec = "40min";
    };
  };

  systemd.services.music-assistant-resume-record = common // {
    description = "Save which Music Assistant queues are playing";
    serviceConfig = common.serviceConfig // {
      ExecStart = "${script}/bin/music-assistant-resume record";
    };
  };

  systemd.timers.music-assistant-resume-record = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
      AccuracySec = "5s";
    };
  };
}
