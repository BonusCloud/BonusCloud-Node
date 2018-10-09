# Installation procedure
mkdir bxc && cd bxc
wget https://github.com/haibochu/BonusCloud-Node/raw/master/mipsel-lede/bxc-start
chmod +x bxc-start

# Run bxc-start for intial setup, bxc-stop & bxc-status will be created automaticly during setup.
./bxc-start # Start bxc client
./bxc-stop # Stop bxc client
./bxc-status # Status of bxc