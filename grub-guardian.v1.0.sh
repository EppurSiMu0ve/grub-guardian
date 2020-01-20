#!/usr/bin/env bash

# -----------------------------------------------------
# Script : grub-guardian
#
# Descrição		: Configura senha para restringir acesso
#				: ao modo de edição do Grub.
# Versão		: 1.0
# Autor			: Eppur Si Muove
# Contato		: eppur.si.muove.89@keemail.me
# Criação 		: 02/12/2019
# Modificação	: 19/01/2020
# Licença		: GNU/GPL v3.0
# -----------------------------------------------------
# Uso : basta rodar o script como usuario root que ele
# vai te pedir os dados necessários.
# -----------------------------------------------------

# testa se o usuário está logado como root
[[ $(id -u) -ne 0 ]] && echo "Para executar o programa é necessário estar logado como root." && exit 1

# variáveis
grubcfg="/boot/grub/grub.cfg"
custom40="/etc/grub.d/40_custom"
linux10="/etc/grub.d/10_linux"
linux10bkp="/root/10_linux_backup"
local_correto="Digite o local correto para"
local_pergunta="não se encontra nesse diretório padrão do sistema.\nGostaria de informar o local correto do arquivo ? (s/n) : "
erro_local="O programa não pode continuar sem saber a localização correta \ndos arquivos necessário para a configuração do Grub. Tente novamente quando tiver essa informação em mãos."

echo "
------------------------------------------------------
Para que o script possa executar corretamente, faz-se
necessário saber se os arquivos de configuração do grub
estão no diretório padrão.
------------------------------------------------------
"

# testa se os arquivos necessários estão no diretórios padrão do linux
if [[ ! -f "$grubcfg" ]]; then
	echo -e -n "O arquivo $grubcfg $local_pergunta"
	read confirma
	[[ "$confirma" != "s" ]] &&	echo -e $erro_local &&	exit 1 || read -p "$local_correto $grubcfg: " grubcfg
elif [[ ! -f "$custom40" ]]; then
	echo -e -n "O arquivo $custom40 $local_pergunta"
	read confirma
	[[ "$confirma" != "s" ]] && echo -e "$erro_local" && exit 1 || read -p "$local_correto $custom40: " custom40
elif [[ ! -f "$linux10" ]]; then
	echo -e -n "O arquivo $linux10 $local_pergunta"
	read confirma
	[[ "$confirma" != "s" ]] && echo -e "$erro_local" && exit 1 || read -p "$local_correto $linux10: " linux10
else
	echo -e "Todos os arquivos de configuração estão em seus diretórios padrões.\n"
fi

echo "
------------------------------------------------------
Primeiramente você deve definir um nome de usuário
e uma senha para podeá ter acesso às opções do Grub.
Dica: não é necessário ser um usuário já cadastrado no sistema.
------------------------------------------------------
"

# define usuário e senha para acesso às opções do Grub
echo -e "Criando usuário e gerando o hash pbkdf2 da senha . . .\n"
read -p "Usuário: " usuario
grub-mkpasswd-pbkdf2 | tee pbkdf2

# exemplo de conteúdo da variável pbkdf2 se tudo ocorrer corretamente:
# --------------------------------------------------------------------------
# Digite a senha:
# Reenter password:
# PBKDF2 hash of your password is grub.pbkdf2.sha512.10000.0CB0060DE15EF7CAFF
# D25492129253E4AB0F6E0C35E1A08FA7E71828CC20A31CD56A8E0E1E1973BB0503AF75CB33ABBD88A
# 739062D6C9B3FCA40289C5ECB7746.5BE05E3A9F2F90BC8CD1D36FD8162EB2384A75BB1A40F947DC0
# 5274A742AF5481CDDD322206789D3718FC8C5AA85C9DF7304C1C4E00EB21852856118012EE360

# exemplo de conteúdo da variável pbkdf2 se houver erro:
# --------------------------------------------------------------------------
# Digite a senha:
# Reenter password:

# pega somente o hash de dentro da variável pbkdf2 e coloca na hash_puro
echo -e "Processando o hash . . .\n"
hash_puro=$(sed -n -e 's/^.*\(grub.pbkdf2\)/\1/p' pbkdf2)
rm pbkdf2

# se as senhas não baterem, hash_puro estará vazio, sair com status de erro.
[[ -z "hash_puro" ]] && exit 1

# modifica arquivo 40_custom para reconhecer o usuario e senha
# criados no comando grub-mkpasswd-pbkdf2
echo -e "Atualizando informações no arquivo $custom40 . . .\n"
echo "set superusers=\"$usuario\"" >> "$custom40"
echo "password_pbkdf2 $usuario $hash_puro" >> "$custom40"

# reconfigurar o arquivo de configuração grub.cfg
echo -e "Reconfigurando o arquivo de configuração do grub $grubcfg . . .\n"
grub-mkconfig -o "$grubcfg"

# faz uma cópia do arquivo de configuração original 10_linux
# para ficar guardado caso seja necessário utilizá-lo posteriormente
echo -e "\nFazendo backup de $linux10 para $linux10bkp . . ."
cp -f "$linux10" "$linux10bkp"

# adiciona o parâmetro --unrestrict em algumas linha dentro de 10_linux
echo -e "\nRestringindo apenas o modo de edição do Grub . . .\n"
sed -i "s/grub_quote)' \${CLASS}/grub_quote)' --unrestricted \${CLASS}/g" "$linux10"

# atualiza o grub
update-grub

echo "
Operação finalizada!
Basta reiniciar o computador e tentar entrar em
modo de edição do Grub. Será te pedido o usuário e senha cadastrados para tal.
"
exit 0
