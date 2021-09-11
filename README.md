# Create an Ubuntu VM on Windows 10's Hyper-V

## VM Creation

### Create the VM

In Hyper-V, create a new Generation 2 Virtual Machine with at least 4096 MB
(recommend 8192 MB) of RAM, using a recent Ubuntu desktop
[image](https://ubuntu.com/download/desktop).

Open the VM's settings, and under "Security", deselect the checkbox labeled
"Enable Secure Boot". If you don't do this, then the VM will not be able
to boot.

Take note of the VM-name you assign.

### Install the OS

During the initial boot, select the options to install Ubuntu on the VM.
Do not select the option to auto-login, or else enhanced sessions will
not work.

### Setup Enhanced Sessions

Execute the following commands on the Ubuntu VM:

```bash
wget https://raw.githubusercontent.com/Microsoft/linux-vm-tools/master/ubuntu/18.04/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```

You may need to reboot the VM and/or run `./install.sh` multiple times.

Once the install script is done, run the following script to edit the
XRDP configuration to support Hyper-V on Windows 10:

```bash
sudo sed \
  -i \
  -e 's/^port=.*$/port=vsock:\/\/-1:3389/' \
  -e 's/^use_vsock=.*$/use_vsock=false/' \
  '/etc/xrdp/xrdp.ini'
```

### Configure Windows to connect

Open PowerShell as an Administrator, and run the following command:

```ps
Set-VM -VMName "ubuntu-vm-name" -EnhancedSessionTransportType HvSocket
```

### Boot the VM

The next time you boot the VM and connect to it through Hyper-V, you will
be presented with the XRDP login screen.

## Additional configuration

T