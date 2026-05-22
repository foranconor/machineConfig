# myCoolMachine — Fresh Install Setup

## Scripted
```
sudo apt update
sudo apt install git linuxcnc-ethercat
git config --global user.name "Conor Foran"
git config --global user.email "foranconor@gmail.com"
ssh-keygen -t ed25519 -C "foranconor@gmail.com" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub   # add this to GitHub before continuing
git clone git@github.com:foranconor/machineConfig.git ~/repos/machineConfig
bash ~/repos/machineConfig/deploy.sh
```

## Manual steps — EtherCAT permissions
- [ ] Create udev rule so `/dev/EtherCAT0` is accessible without sudo:
  ```
  echo 'KERNEL=="EtherCAT[0-9]*", MODE="0666"' | sudo tee /etc/udev/rules.d/99-ethercat.rules
  sudo udevadm control --reload-rules
  ```

## Manual steps — System
- [ ] `/etc/ethercat.conf` — set `MASTER0_DEVICE` to NIC MAC address, `DEVICE_MODULES="generic"`, then `sudo systemctl enable --now ethercat`
- [ ] Auto-login: `/etc/lightdm/lightdm.conf` → `autologin-user=conor`
- [ ] Screensaver: Settings Manager → Screensaver → disable
