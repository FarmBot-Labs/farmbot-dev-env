#!/bin/bash
# Just a quick script i made to provision a linux Box for Farmbot Development.
export TWD=$(pwd)
# Make sure we are NOT root
if [ "$(whoami)" == "root" ]; then
  echo "This script should NOT be run as root. If root is needed, it will ask."
  exit 1
fi

# Detect System
export DISTRO=$(lsb_release -si)
export ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
export PACKAGES=$( cat ../packages/$DISTRO"_packages.source" )

if [ -z "$PACKAGES" ]; then
  echo "No packages defined for $DISTRO"
  echo "Contact Someone probably."
  exit 1
fi

# Logging ftw.
echo "Provisioning $DISTRO Linux"

# Make sure we are on x86_64
if [ "$ARCH" != "64" ]; then
  echo "Most packages require 64 bits. Bailing."
  exit 1
fi

# Install dependencies and such.
if [ "$DISTRO" == "Arch" ]; then
  sudo pacman -S $PACKAGES
  sudo systemctl enable mongodb
  sudo systemctl start mongodb

elif [ "$DISTRO" == "Ubuntu" ] || [ "$DISTRO" == "Debian" ]; then
  sudo apt-get install -y $PACKAGES || { echo "Installation failed" && exit; }
  sudo systemctl enable mongodb
  sudo systemctl start mongodb

elif [ "$DISTRO" == "Fedora" ]; then
  echo "i dont know how to yum."
fi

# Install asdf-vm for node-js
if [ -d ~/.asdf ]; then
  echo "Asdf-vm already installed? Hopefully something doesn't break."
else
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.1.0
  echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc
  echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
  source $HOME/.asdf/asdf.sh

  asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  asdf install nodejs 6.4.0
  asdf global nodejs 6.4.0

  # You're welcome rick
  if [ -n $(which fish) ]; then
    echo "FISH detected."
    echo 'source ~/.asdf/asdf.fish' >> ~/.config/fish/config.fish
    mkdir -p ~/.config/fish/completions; cp ~/.asdf/completions/asdf.fish ~/.config/fish/completions
    echo "Installed FISH asdf command completions"
  fi

fi

# install Ruby.
if [ -d $HOME/.rvm/rubies/ruby-2.3.1/ ]; then
  echo "Ruby 2.3.1 Already installed."
else  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  curl -sSL https://get.rvm.io | bash -s stable
  source $HOME/.rvm/bin/rvm
  rvm install ruby 2.3.1
  gem install bundler
fi

# Install Arduino and stuff, to build the farmbot-arduino-firmware
ARDUINO_VERSION="1.6.11"
if [ $(uname) == "Linux" ]; then
  ARDUINO_PLATFORM="linux"
elif [ $(uname) == "Darwin" ]; then
  ARDUINO_PLATFORM="darwin"
fi

ARDUINO_NAME="arduino-$ARDUINO_VERSION-$ARDUINO_PLATFORM$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')"

if [ -d $HOME/arduino/ ]; then
  echo "Arduino Already installed."
else
  mkdir $HOME/arduino; cd $HOME/arduino
  echo "Downloading $ARDUINO_NAME"
  wget http://arduino.cc/download.php?f=/$ARDUINO_NAME.tar.xz -O $ARDUINO_NAME.tar.xz
  echo "Extracting $ARDUINO_NAME"
  tar -xf $ARDUINO_NAME.tar.xz
  rm $ARDUINO_NAME.tar.xz
  mv * $ARDUINO_NAME
  cd $ARDUINO_NAME

  # I don't actually know what this does?
  sh -c ./install.sh
  export PATH=$PATH:$HOME/arduino/$ARDUINO_NAME
  echo "PATH=$PATH:$HOME/arduino/$ARDUINO_NAME" >> $HOME/.bashrc
fi

mkdir /tmp/farmbot_provision
cd /tmp/farmbot_provision

sudo pip install jinja2 glob2

git clone git://github.com/amperka/ino.git
cd ino
sudo make install

if [ -d $HOME/farmbot/ ]; then
  echo "Dirs already found. Bailing."
else
  # Create the directories, and clone the farmbot projects into them.
  mkdir $HOME/farmbot
  cd $HOME/farmbot
  echo "Use ssh for Git Clones? Y/n"
  read GITQ
  if [ -z $GITQ ] || [ $GITQ == "y" ] || [ $GITQ == "yes"  ] || [ $GITQ == "Y"  ]; then
    FB_GIT='ssh://git@github.com/FarmBot'
  else
    FB_GIT='https://github.com/FarmBot'
  fi

  git clone $FB_GIT/farmbot-raspberry-pi-controller.git
  git clone $FB_GIT/farmbot-web-frontend.git
  git clone $FB_GIT/farmbot-arduino-firmware.git
  git clone $FB_GIT/farmbot-js.git
  git clone $FB_GIT/farmbot-serial.git
  git clone $FB_GIT/farmbot-resource.git

  # These don't fit the naming scheme
  git clone $FB_GIT/FarmBot-Web-API.git
  git clone $FB_GIT/mqtt-gateway.git
fi

echo "Should I spin up a local debug instance? (y/N)"
echo "[NOTE] There is no error checking for this. You will probably need to get your hands dirty after this fails."
cd $TWD
echo $TWD
read STARTR
if [[ "$STARTR" =~ ^[Yy]$ ]]; then
  ./start_local_server.sh
else
  exit 0;
fi
