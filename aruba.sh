#!/bin/bash

# Verifica se o usuário é o root
if [[ $(id -u) -ne 0 ]]; then
    echo "Este script precisa ser executado com privilégios de root."
    exit 1
fi

# Define o caminho do arquivo a ser baixado e do diretório TFTP
ARQUIVO="aruba.bin"
DIRETORIO_TFTP="/srv/tftp/"

# Verifica se o servidor TFTP está instalado
if [ $(dpkg-query -W -f='${Status}' tftpd-hpa 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  echo "O servidor TFTP não está instalado. Instalando agora..."
  # Instala o servidor TFTP
  sudo apt-get update
  sudo apt-get install tftpd-hpa -y
  # Verifica se a instalação foi bem sucedida
  if [ $(dpkg-query -W -f='${Status}' tftpd-hpa 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    echo "Falha ao instalar o servidor TFTP."
    exit 1
  else
    echo "O servidor TFTP foi instalado com sucesso."
  fi
else
  echo "O servidor TFTP já está instalado."
fi

# Verifica se o curl está instalado
if ! command -v curl &> /dev/null
then
  echo "O curl não está instalado. Instalando agora..."
  # Instala o curl
  sudo apt-get update
  sudo apt-get install curl -y
  # Verifica se a instalação foi bem sucedida
  if ! command -v curl &> /dev/null
  then
    echo "Falha ao instalar o curl."
    exit 1
  else
    echo "O curl foi instalado com sucesso."
  fi
else
  echo "O curl já está instalado."
fi

if [ -e "$DIRETORIO_TFTP/$ARQUIVO" ];
then
  echo "já existe um firmware na pasta tftp"
else
  # Faz o download do arquivo e o coloca na pasta do TFTP
  echo "Baixando o arquivo $ARQUIVO..."
  curl -L "https://drive.google.com/uc?export=download&id=1iVQGn2MKUTilbFLJtX3IWcowS2Xcc9T3" -o "$ARQUIVO"

  # Move o arquivo para a pasta do TFTP
  echo "Movendo o arquivo $ARQUIVO para a pasta do TFTP..."
  sudo mv "$ARQUIVO" "$DIRETORIO_TFTP"

  # Define as permissões corretas para o arquivo na pasta do TFTP
  echo "Definindo as permissões corretas para o arquivo $ARQUIVO na pasta do TFTP..."
  sudo chmod 666 "$DIRETORIO_TFTP$ARQUIVO"

  echo "O arquivo $ARQUIVO foi baixado e colocado na pasta do TFTP com sucesso."
fi

ip=$(hostname -I | awk '{print $1}')


# Configuração da porta serial
stty -F /dev/ttyS0 9600 cs8 -cstopb -parenb

#le o serial do AP
read -p "Digite o Serial do AP a ser configurado: " sn


# Encripta em SHA-1
hash=$(echo -n "$sn" | sha1sum | cut -d ' ' -f 1)

# Concatena na string
resultado="proginv system ccode CCODE-RW-$hash"

#echo "Resultado: $resultado"

echo "$resultado" | sudo tee /dev/ttyS0

sleep 2

echo "invent -w" | sudo tee /dev/ttyS0

sleep 10

echo "upgrade os 0 $ip:$ARQUIVO" | sudo tee /dev/ttyS0

# Aguarda a gravação do firmware no partição 0
sleep 250

echo "upgrade os 1 $ip:$ARQUIVO" | sudo tee /dev/ttyS0

# Aguarda a gravação do firmware no partição 1
sleep 250

echo "boot" | sudo tee /dev/ttyS0
