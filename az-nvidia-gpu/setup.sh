distro=$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f2 | tr -d '."')
arch=$(uname -m)
echo "Distro: $distro"
echo "Arch: $arch"
url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${distro}/${arch}/cuda-keyring_1.1-1_all.deb"

# check if there exists any file that contains cuda-distro-arch.list in the folder '/etc/apt/sources.list.d/'
# if it exists, then remove any older cuda-ubuntu*.list files other than this file
# if it doesn't exist then remove all cuda-ubuntu*.list files and download from the url

if [ -f /etc/apt/sources.list.d/cuda-${distro}-${arch}.list ]; then
    echo "cuda-${distro}-${arch}.list exists"
    for file in /etc/apt/sources.list.d/cuda-*.list; 
    do
        if [[ "$file" != "/etc/apt/sources.list.d/cuda-${distro}-${arch}.list" ]]; then
            sudo rm "$file"
        fi
    done
else
    echo "cuda-${distro}-${arch}.list does not exist"
    sudo rm /etc/apt/sources.list.d/cuda-ubuntu*.list
    sudo rm /etc/apt/sources.list.d/*cuda_repos_ubuntu*.list
    sudo apt-key del 7fa2af80
    wget $url
    sudo dpkg -i cuda-keyring_1.1-1_all.deb    
fi

echo "nvidia container toolkit setup"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update && sudo apt upgrade -y
sudo apt install -y nvidia-cuda-toolkit
sudo apt install -y python3.10-venv
sudo apt install -y nvidia-container-toolkit

# echo "install pyenv"
# curl https://pyenv.run | bash

# echo "setting up poetry"
# curl -sSL https://install.python-poetry.org | python3 -

echo "checking if docker is installed"
if ! command -v docker &> /dev/null
then
    echo "docker could not be found"
    echo "adding docker's official GPG key"
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to Apt sources:

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    echo "installing docker"
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "adding user to docker group"
    sudo usermod -aG docker $USER

    echo "restarting docker"
    sudo systemctl restart docker
    sudo systemctl enable docker
else
    echo "docker is already installed"
fi

# set up a git ssh key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# export PYENV_ROOT="$HOME/.pyenv"
# [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"
# eval "$(pyenv virtualenv-init -)"

cat << 'EOF' >> ~/.bashrc

# start ssh-agent
eval "$(ssh-agent -s)"

# add the ssh key to the ssh-agent
ssh-add ~/.ssh/id_ed25519

export PATH=$PATH:$HOME/.local/bin

EOF

source ~/.bashrc

# print the ssh public key and echo "add the ssh public key to github account and press enter to continue"
cat ~/.ssh/id_ed25519.pub
read -p "Add the ssh public key to github account and press enter to continue"

ssh -T git@github.com
