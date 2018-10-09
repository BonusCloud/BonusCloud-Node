# Installation procedure
mkdir bxc && cd bxc
wget http://github.com/haibochu/BonusCloud-Node/raw/mipsel-lede/aarch32-lede/bxc-start
chmod +x bxc-start

# Run bxc-start for intial setup, bxc-stop & bxc-status will be created automaticly during setup.
./bxc-start # Start bxc client
./bxc-stop # Stop bxc client
./bxc-status # Status of bxc