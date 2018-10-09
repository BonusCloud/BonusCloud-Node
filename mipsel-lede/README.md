# Installation procedure
mkdir bxc && cd bxc
wget https://github.com/BonusCloud/BonusCloud-Node/raw/master/aarch64-N1/bxc-start
chmod +x bxc-start

# Run bxc-start for intial setup, bxc-stop & bxc-status will be created automaticly during setup.
./bxc-start # Start bxc client
./bxc-stop # Stop bxc client
./bxc-status # Status of bxc