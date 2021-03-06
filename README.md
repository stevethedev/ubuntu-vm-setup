# Create an Ubuntu VM on Windows 10's Hyper-V

These instructions are intended to help create fresh Ubuntu 20 VMs on
Windows 10 Professional Edition, using Hyper-V. Since this is not
intended to be run on bare-metal Ubuntu installations (nor on pre-existing
VMs that host important information) some compromises have been made
to streamline the process.

One such compromise is the use of `wget ... | bash`, which is dangerous
and should not be used on non-virtual machines or machines that currently
host important information.

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

Run this command to prime the terminal for accepting `sudo` commands.
This will prevent the following scripts from triggering the password
request query and swallowing the rest of the script as password attempts.

```bash
sudo ls > /dev/null
```

Execute the following commands on the Ubuntu VM:

```bash
wget https://raw.githubusercontent.com/Microsoft/linux-vm-tools/master/ubuntu/18.04/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```

You may need to reboot the VM and/or run `./install.sh` multiple times.

Once the installation script is done, run the following script to edit the
XRDP configuration to support Hyper-V on Windows 10:

```bash
sudo apt install -y crudini
sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak
sudo crudini --set /etc/xrdp/xrdp.ini Globals port 'vsock://-1:3389'
sudo crudini --set /etc/xrdp/xrdp.ini Globals use_vsock false
```

### Configure Windows to connect

Open PowerShell as an Administrator, and run the following command:

```ps
Set-VM -VMName "ubuntu-vm-name" -EnhancedSessionTransportType HvSocket
```

### Boot the VM

The next time you boot the VM and connect to it through Hyper-V, you will
be presented with the XRDP login screen. Note that Hyper-V can be weird
about this, and you may need a complete stop/start of the VM before the
host machine recognizes that it can connect with Enhanced Sessions.

## Additional configuration

There is a configuration helper that automates a lot of the boring parts
of configuring a VM. This includes installing programming languages,
configuring Git, setting up SSH support, etc.

```bash
wget -q -O - 'https://raw.githubusercontent.com/stevethedev/ubuntu-vm-setup/master/setup-vm.sh' | bash
```
