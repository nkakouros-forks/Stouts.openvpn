#!/usr/bin/env bats

if ! command -V openvpn &>/dev/null; then
  echo "The program 'openvpn' is not installed. Install it and rerun the test" >&2
  exit 1
fi

if  [ "${config:-unset}" == "unset" ]; then
  echo "Missing environment variable 'config' that points to ovpn file to use." >&2
  exit 1
fi

function setup {
  config_file=$config
  config_dir=${config_file%/*}
  config_file=${config_file##*/}
  if [ "$config_dir" == "$config_file" ]; then
    config_dir='.'
  fi
  # Create temp file for writing
  temp_file=$(mktemp)
}

@test "Connect to VPN" {
  local -i retry_interval=5
  local -i retries=3
  local -i max_time=$retry_interval*$retries

  run openvpn \
    --cd $config_dir \
    --config $config_file \
    --connect-retry $retry_interval \
    --connect-retry-max $retries \
    --writepid $temp_file \
    --daemon

  dev=$(grep dev $config)
  dev=${dev//dev /}
  dev=${dev// /}

  SECONDS=0
  while ! grep $dev <<< "$(ip link show up)"; do
    if  [ $SECONDS -gt $max_time ]; then
      break
    fi
    sleep $(($retry_interval+1))
  done

  [ "$status" -eq 0 ]
}

function teardown() {
  kill $(cat $temp_file)
  rm $temp_file
}
