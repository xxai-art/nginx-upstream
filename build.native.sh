#!/usr/bin/env bash

DIR=$(realpath $0) && DIR=${DIR%/*}
cd $DIR
set -ex

if ! [ -x "$(command -v dasel)" ]; then
  go install github.com/tomwright/dasel/v2/cmd/dasel@master
fi

export NATIVE=1

build() {
  name=$1
  source sh/cflag.sh

  cargo build $RUST_FEATURES --release --target $RUST_TARGET

  pre=/opt/bin/$name

  if [ -f "$pre" ]; then
    rm -rf /tmp/$name
    sudo mv $pre /tmp
  fi

  sudo mkdir -p /opt/bin
  sudo mv target/$RUST_TARGET/release/$name /opt/bin/$name

  case $(uname -s) in
  Linux*)
    systemctl restart $name || ./service.sh $name
    sleep 5

    if ! systemctl is-active --quiet $name.service; then
      journalctl -u $name -n 10 --no-pager --no-hostname
      echo -e "\n\n ❗服务启动失败\n\n"
      rm -rf /tmp/$name.failed
      mv /opt/bin/$name /tmp/$name.failed
      mv /tmp/$name /opt/bin/$name
      systemctl restart $name && sleep 5 || true
    fi

    systemctl status $name --no-pager
    journalctl -u $name -n 10 --no-pager --no-hostname
    ;;
  esac
}

build $(cat Cargo.toml | dasel -r toml 'package.name' | tr -d "'")
