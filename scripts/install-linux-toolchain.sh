#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:haxe/releases -y
sudo apt-get update
sudo apt-get install -y \
  git \
  make \
  gcc \
  g++ \
  haxe \
  libpng-dev \
  libturbojpeg-dev \
  libvorbis-dev \
  libopenal-dev \
  libsdl2-dev \
  libglu1-mesa-dev \
  libmbedtls-dev \
  libuv1-dev \
  libsqlite3-dev

sudo apt-get install -y hashlink || true

if ! command -v hl >/dev/null 2>&1; then
  git clone --depth 1 https://github.com/HaxeFoundation/hashlink /tmp/hashlink
  make -C /tmp/hashlink
  sudo make -C /tmp/hashlink install
fi

haxe --version
command -v hl
