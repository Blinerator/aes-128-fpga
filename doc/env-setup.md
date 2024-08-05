# Environment Setup Instructions

This setup guide is intended for Debian on WSL.



- Install [WSL](https://learn.microsoft.com/en-us/windows/wsl/installf).
    - Install Debian for WSL via the Microsoft Store.
- In your Debian terminal, enter `sudo apt-get update`
- Install Questa (ModelSim)
    - Go to the [download](https://www.intel.com/content/www/us/en/software-kit/825277/ intel-quartus-prime-lite-edition-design-software-version-23-1-1-for-linux.html) page.
    - Navigate to "Individual Files" under "Downloads".
    - Download Questa-Intel® FPGA and Starter Editions for Linux.
    - In your Debian terminal, navigate to where the .run file was downloaded and enter `chmod  +x yourfilename.run`.
    - Enter `./yourfilename.run` to install Questa.
    - Follow the steps in this [tutorial](https://vhdlwhiz.com/free-vhdl-simulator-alternatives/) to set up a license for Questa (Questa-Intel FPGA Starter Edition (ModelSim) >> License request)
      - Register for an account to use the Intel FPGA Self-Service Licensing Center.
      - Select the license for Questa Starter Edition
      - Register your computer. To get your MAC, enter `ip link`. The MAC is listed after link/ether.
- Install Python 3, Python dev packages, GCC, GNU make: 
    - `sudo apt-get install make gcc g++ python3 python3-dev python3-pip`
- It's good practice to use a virtual environment with Python:
    - Install venv: `sudo apt install python3.11-venv` (I'm using Python 3.11)
    - Create a virtual environment in the current directory: `python3 -m venv RTL1`
    - Activate it: `source RTL1/bin/activate`
    - Your shell prompt should have (RTL1) pre-fixed to it.
- Modify .bashrc file:
    - Open .bashrc file with nano: `nano ~/.bashrc`
    - Add license file for Questa: `export LM_LICENSE_FILE="/path_to_license/LICENSE-FILE.  dat:$LM_LICENSE_FILE`
    - Add vsim to PATH: `export PATH=$PATH:/path_to_questa/questa_fse/bin`
    - (WSL Only) WSL does not have a static eth0 MAC. Therefore you need to set a virtual MAC:
      - `sudo ip link add vmnic0 type dummy`
      - `sudo ip link set vmnic0 addr 00:15:5d:35:63:f0` (replace MAC with whatever you used for the Questa license)
    - (Optional) Automatically activate the RTL virtual environment: `source  path_to_your_environment/RTL1/bin/activate`
    - (Optional) Set default start directory: `cd your_directory`
    - Close .bashrc
- Install [cocotb](https://docs.cocotb.org/en/stable/install.html) (development version): 
    - `pip install git+https://github.com/cocotb/cocotb@master`
- Install git: `sudo apt install git`
- Verify everything is working using a cocotb example testbench:
    - Clone down the cocotb repo: `git clone https://github.com/cocotb/cocotb.git`
    - `cd /cocotb/examples/adder/tests`
    - `make SIM=questa`