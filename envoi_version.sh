#!/bin/sh
#####
# Envoi des fichiers pour les versions GAEL/GESSICA
#
# Pr▒requis :
# - l'▒change de cl▒ SSH depuis le serveur GAEL/GESSICA vers le serveur reseau doit ▒tre effectu▒
# - l'▒change de cl▒ SSH depuis le serveur CEN0003 vers le serveur GAEL/GESSICA doit ▒tre effectu▒
#
# Remarques :
# - Ce script doit ▒tre plac▒ dans le m▒me r▒pertoire que les archives ▒ envoyer
#
# Param▒tres d'entr▒e :
# - application concern▒e [GES|GAW]
# - ident de la centrale sur 4 chiffres
#
# Version 1.0 - Dr▒an Fabien - cr▒ation
#####

# EXIT : Sortie en ERR si le nombre de param▒tres est invalide
if [ $# -ne 2 ]
then
        echo "ERREUR : Nombre de param▒tres invalide !"
        echo "Param▒tres d'entr▒e :"
        echo "1- application concern▒e [GES|GAW]"
        echo "2- ident de la centrale sur 4 chiffres"
        exit 1
fi

### D▒claration des variables

user_version="sigadm"                                           # Utilisateur avec lequel on passe la version
FIC_HOSTS=/etc/hosts.nagios                                     # Fichier hosts utilis▒
appli=$1                                                        # Application concern▒e [GES|GAW]
ident=$2                                                        # Ident de la centrale
CODE_RETOUR=0                                                   # Initialisation de la variable pour les codes retour
rep=`pwd`                                                       # R▒pertoire courant
LOG=$rep/logs/$2_$1_envoi_version_`date +%Y%m%d_%H%M`.log       # Nom du log (si modifi▒, il faut modifier en cons▒quence l'▒puration des logs en fin de script)
duree_epur=365                                                  # Dur▒e de r▒tention des logs avant ▒puration (en jours)

### Fonctions

message () {
        # $1 => [INF|ERR]
        # $2 => message ▒ afficher
        echo "| "`date +"%D | %H:%M"`" | $1 | $2" | tee -a $LOG
}

### Gestion des logs

# Cr▒ation du r▒pertoire de logs si celui-ci n'existe pas
if [ ! -d `dirname $LOG` ]
then
        mkdir `dirname $LOG`
        if [ $? -ne 0 ]
        then
                echo "ERREUR lors de la cr▒ation du r▒pertoire de logs !"
                exit 1
        fi
fi

# Initialisation du log et de la sortie ▒cran
echo "================================================================================" | tee -a $LOG
echo "| ********* SCRIPT D ENVOI DES PACKAGES POUR LES VERSIONS GESSICA/GAEL *********" | tee -a $LOG
echo "================================================================================" | tee -a $LOG

# V▒rification du contenu de la variable appli et d▒finition des variables alias_serveur et rep_cible_pkg
case $appli in
        "GES")
                alias_serveur="GESSICA"
                message "INF" "Application : ${alias_serveur}"
                rep_cible_pkg="/reorgges"
                message "INF" "R▒pertoire de d▒p▒t des sources : ${rep_cible_pkg}"
                fic_conf_ftp_win="/gessica/installAppli/ges.conf"
                message "INF" "Fichier de configuration contenant les informations pour la connexion FTP au Windows : $fic_conf_ftp_win"
                ;;
        "GAW")
                alias_serveur="GAEL"
                message "INF" "Application : ${alias_serveur}"
                rep_cible_pkg="/reorggae"
                message "INF"  "R▒pertoire de d▒p▒t des sources : ${rep_cible_pkg}"
                fic_conf_ftp_win="/gael/installAppli/gae.conf"
                message "INF" "Fichier de configuration contenant les informations pour la connexion FTP au Windows : $fic_conf_ftp_win"
                ;;
        *)
                message "ERR" "Application inconnue ! choix [GES|GAW]"
                exit 1
                ;;
esac

# Nom de l'archive unix
NB=`ls -l ${appli}*_UNIX.tar.gz 2> /dev/null | wc -l`
if [ $NB -eq 1 ]
then
        pkg_unix=`ls ${appli}*_UNIX.tar.gz`
        message "INF" "Package Unix ▒ envoyer : ${pkg_unix}"
else
        message "ERR" "Pas de package UNIX trouv▒ dans le r▒pertoire courant ou le r▒pertoire courant coutient plusieurs packages UNIX ! [${appli}*_UNIX.tar.gz]"
        CODE_RETOUR=1
fi

# Nom de l'archive windows
NB=`ls -l ${appli}*_WINDOWS.zip 2> /dev/null | wc -l`
if [ $NB -eq 1 ]
then
        pkg_windows=`ls ${appli}*_WINDOWS.zip`
        message "INF" "Package Windows ▒ envoyer : ${pkg_windows}"
else
        message "ERR" "Pas de package WINDOWS trouv▒ dans le r▒pertoire courant ou le r▒pertoire courant coutient plusieurs packages WINDOWS ! [${appli}*_WINDOWS.zip]"
        CODE_RETOUR=1
fi

# EXIT : Sortie en erreur si les packages ne sont pas tous les 2 pr▒sents
if [ $CODE_RETOUR -eq 1 ]
then
        exit 1
fi

### V▒rification de la connexion au serveur distant et r▒cup▒ration du type d'OS
if [ ${ident:0:1} -eq 0 ]
        then NOM_SERVEUR=${ident:1}_A_${alias_serveur}
        else NOM_SERVEUR=${ident}_A_${alias_serveur}
fi

CODE_RETOUR=`grep -c ${NOM_SERVEUR}$ ${FIC_HOSTS}`
case $CODE_RETOUR in
        0)
                message "ERR" "Le serveur ${NOM_SERVEUR} n'est pas pr▒sent dans le fichier ${FIC_HOSTS} !"
                exit 1
                ;;
        1)
                ip_serveur=`grep ${NOM_SERVEUR}$ ${FIC_HOSTS} | awk '{print $1}'`
                message "INF" "L'IP du serveur ${NOM_SERVEUR} est : ${ip_serveur}"
                ;;
        *)
                message "ERR" "Le serveur ${NOM_SERVEUR} est pr▒sent plus d'une fois dans le fichier ${FIC_HOSTS} !"
                exit 1
                ;;
esac

CODE_RETOUR=`grep -c "${ip_serveur} " /root/.ssh/known_hosts`
if [ $CODE_RETOUR -eq 0 ]
then
        echo "Saisissez le mot de passe pour la session SSH ${user_version}@${ip_serveur} :"
        ssh-copy-id -i /root/.ssh/id_rsa.pub ${user_version}@${ip_serveur} 2>> $LOG
        if [ $? -eq 0 ]
        then
                message "INF" "Echange de la cl▒ SSH effectu▒e"
        else
                message "ERR" "Probl▒me lors de l'▒change de la cl▒ SSH !"
                sed -i "/${ip_serveur}/d" /root/.ssh/known_hosts 2>> $LOG
                exit 1
        fi
fi

OS=`ssh -o StrictHostKeyChecking=no ${user_version}@${ip_serveur} uname`
case $OS in
        "Linux")
                message "INF" "OS = ${OS}"
                ;;
        "AIX")
                message "INF" "OS = ${OS}"
                ;;
        "")
                message "ERR" "Probl▒me de connexion SSH vers le serveur distant ! [ssh ${user_version}@${ip_serveur} uname]"
                exit 1
                ;;
        *)
                message "ERR" "OS ${OS} inconnu !"
                exit 1
                ;;
esac

### V▒rification de l'espace disque disponible

free_space=`ssh ${user_version}@${ip_serveur} df -k ${rep_cible_pkg} | tail -1 | awk '{print $3}'`

if [[ $free_space = +([0-9]) ]]
then
        message "INF" "Espace disque disponible sur ${ip_serveur}:${rep_cible_pkg} : ${free_space} octets"
else
        message "ERR" "Probl▒me lors de la r▒cup▒ration de l'espace disque disponible sur ${ip_serveur}:${rep_cible_pkg} !"
        exit 1
fi

taille_pkg_win=`du -k ${rep}/${pkg_windows} | awk '{print $1}'`
message "INF" "Taille du package Windows : ${taille_pkg_win} ko"
taille_pkg_unix=`du -k ${rep}/${pkg_unix} | awk {'print $1}'`
message "INF" "Taille du package Unix : ${taille_pkg_unix} ko"

need_space=$((${taille_pkg_win}+${taille_pkg_unix}))

if [ $need_space -lt $free_space ]
then
        message "INF" "Espace disque suffisant pour accepter le package Unix et le package Windows"
else
        message "ERR" "Espace disque insuffisant pour accepter le package Unix et le package Windows ! [espace requis : ${need_space} ko]"
        exit 1
fi

### Soumission des packages ▒ CFT
REM CODE_RETOUR=0
REM date_env_cft=`date +%d%m%Y%H%M`
REM su - cft -c "cftutil send fname=${rep}/${pkg_unix} , nfname=/savreseau/${pkg_unix} , idf=admsyst , ida=IMFA_vers${appli}_${date_env_cft} , part=S${2}100" 1>> $LOG 2>&1
REM if [ $? -ne 0 ] ; then CODE_RETOUR=1 ; else message "INF" "Package Unix soumis ▒ CFT" ; fi
REM su - cft -c "cftutil send fname=${rep}/${pkg_windows} , nfname=/savreseau/${pkg_windows} , idf=admsyst , ida=IMFA_vers${appli}_${date_env_cft} , part=S${2}100" 1>> $LOG 2>&1
REM if [ $? -ne 0 ] ; then CODE_RETOUR=1 ; else message "INF" "Package Windows soumis ▒ CFT" ; fi

REM # EXIT : Sortie en erreur si la soumission ▒ CFT est en ▒chec
REM if [ $CODE_RETOUR -ne 0 ]
REM then
        REM message "ERR" "Un probl▒me est survenu lors de la soumission des packages ▒ CFT !"
        REM exit 1
REM fi

REM ### Attente de la fin des transferts des packages

REM nb_boucle=0             #Nombre de boucle effectu▒e
REM nb_boucle_max=240       #Nombre de boucle maximum ▒ effectuer
REM attente=30              #Temps en seconde entre chaque boucle

REM sleep 1 # pause afin d'▒viter les mauvais retours sur les commandes suivantes
REM until [ `su - cft -c "cftutil listcat part=S${ident}100, state=C, ida=IMFA_vers${appli}_${date_env_cft}" | grep selected | awk '{print $1}'` -eq 0 ]
REM do
        REM # V▒rification qu'il n'y a pas de transferts en erreur
        REM if [ `su - cft -c "cftutil listcat part=S${ident}100, state=DHK, ida=IMFA_vers${appli}_${date_env_cft}" | grep selected | awk '{print $1}'` -ne 0 ]
                REM then
                        REM message "ERR" "Au moins un transfert CFT est en ▒chec !"
                        REM su - cft -c "cftutil listcat part=${ident}100, state=DHK, ida=IMFA_vers${appli}_${date_env_cft}"
                        REM exit 1
        REM fi
        REM # V▒rification que le transfert ne met pas trop temps
        REM if [ $nb_boucle -eq 240 ]
        REM then
                REM message "ERR" "Le transfert CFT tourne depuis $nb_boucle fois $attente secondes. C'est est trop long !"
                REM exit 1
        REM fi
        REM ((nb_boucle++))
        REM if [ $nb_boucle -eq 1 ]
                REM then message "INF" "Transfert CFT, veuillez patientez"
                REM else echo "." | tr -d "\n"
        REM fi
        REM sleep $attente
REM done
REM sleep 1 # pause afin d'▒viter les mauvais retours sur les commandes suivantes
REM echo

REM # V▒rification que les transferts ne sont pas en erreur
REM if [ `su - cft -c "cftutil listcat part=S${ident}100, state=DHK, ida=IMFA_vers${appli}_${date_env_cft}" | grep selected | awk '{print $1}'` -ne 0 ]
        REM then
                REM message "ERR" "Au moins un transfert CFT est en ▒chec !"
                REM su - cft -c "cftutil listcat part=${ident}100, state=DHK, ida=IMFA_vers${appli}_${date_env_cft}"
                REM exit 1
        REM else
                REM message "INF" "Transferts CFT effectu▒s avec succ▒s"
REM fi

### R▒cup▒ration des packages depuis le serveur reseau

CODE_RETOUR=`ssh ${user_version}@${ip_serveur} ssh -o StrictHostKeyChecking=no cft@reseau uname -r > /dev/null ; echo $?`
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "Probl▒me lors du test de connexion SSH !"
        exit 1
else
        message "INF" "Test de connexion SSH depuis ${ip_serveur} vers cft@reseau r▒ussi."
fi

CODE_RETOUR=`ssh ${user_version}@${ip_serveur} scp -q cft@reseau:/savreseau/${pkg_windows} ${rep_cible_pkg} ; echo $?`
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "Probl▒me de r▒cup▒ration du package Windows depuis le serveur reseau !"
        exit 1
else
        message "INF" "Package Windows transf▒r▒ sur le serveur $appli"
fi

CODE_RETOUR=`ssh ${user_version}@${ip_serveur} scp -q cft@reseau:/savreseau/${pkg_unix} ${rep_cible_pkg} ; echo $?`
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "Probl▒me de r▒cup▒ration du package Unix depuis le serveur reseau !"
        exit 1
else
        message "INF" "Package Unix transf▒r▒ sur le serveur $appli"
fi

### R▒cup▒ration des information de connexion FTP vers le Windows dans le fichier de conf de l'installAppli [ges.conf|gae.conf]

FTP_SERVEUR=`ssh ${user_version}@${ip_serveur} grep FTP_SERVEUR $fic_conf_ftp_win | awk -F "=" '{print $2}'`
if [ $? -ne 0 ] ; then CODE_RETOUR=1 ; else message "INF" "Serveur Windows : $FTP_SERVEUR" ; fi
FTP_LOGIN=`ssh ${user_version}@${ip_serveur} grep FTP_LOGIN $fic_conf_ftp_win | awk -F "=" '{print $2}'`
if [ $? -ne 0 ] ; then CODE_RETOUR=1 ; else message "INF" "Utlisateur FTP : $FTP_LOGIN" ; fi
FTP_PASSWD=`ssh ${user_version}@${ip_serveur} grep FTP_PASSWD $fic_conf_ftp_win | awk -F "=" '{print $2}'`
if [ $? -ne 0 ] ; then CODE_RETOUR=1 ; else message "INF" "Mot de passe FTP : *****" ; fi

# EXIT : Sortie en erreur si la r▒cup▒ration des informations de connexion FTP est en ▒chec
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "un probl▒me est survenu lors de la r▒cup▒ration des informations de connexion FTP !"
        exit 1
fi

### Envoi en FTP du package Windows

CODE_RETOUR=`ssh ${user_version}@${ip_serveur} echo -e "ftp -nv $FTP_SERVEUR <<EOF\nuser ${FTP_LOGIN} ${FTP_PASSWD}\nbinary\nmkdir tmp_version\ncd tmp_version\nlcd ${rep_cible_pkg}\nput ${pkg_windows}\nEOF" 2> /dev/null | ksh | grep -ic "226 Transf"`
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "Probl▒me lors du transfert FTP du package vers le serveur Windows !"
        exit 1
else
        message "INF" "Transfert FTP du package vers le serveur Windows effectu▒."
fi

### Epuration des packages temporaires

CODE_RETOUR=`ssh ${user_version}@${ip_serveur} rm ${rep_cible_pkg}/${pkg_windows} ; echo $?`
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "Probl▒me lors de la suppression du fichier ${rep_cible_pkg}/${pkg_windows} sur le serveur ${ip_serveur} !"
        exit 1
else
        message "INF" "Suppresion du fichier ${rep_cible_pkg}/${pkg_windows} sur le serveur ${ip_serveur} r▒ussi."
fi

CODE_RETOUR=`ssh ${user_version}@${ip_serveur} ssh cft@reseau rm /savreseau/${pkg_unix} /savreseau/${pkg_windows} ; echo $?`
if [ $CODE_RETOUR -ne 0 ]
then
        message "ERR" "Probl▒me lors de la suppression des packages sur le serveur reseau !"
        exit 1
else
        message "INF" "Suppression des packages sur le serveur reseau r▒ussi."
fi

# Fin de log et de la sortie standard en cas de succ▒s
echo "================================================================================" | tee -a $LOG
echo "| ********** ENVOI DES PACKAGES POUR LES VERSIONS GESSICA/GAEL REUSSI **********" | tee -a $LOG
echo "================================================================================" | tee -a $LOG

# Epuration des logs
find `dirname $LOG` -type f -name "*_envoi_version_*.log" -mtime +$duree_epur -exec rm {} \;

exit 0
