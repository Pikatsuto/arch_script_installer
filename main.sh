#!/bin/bash
set echo off
cp -R ../arch_script_installer /mnt/home/

function packet_install {
    if [ -e /home/arch_script_installer/powerpill_present ]
    then
        sudo powerpill $*
    else
        sudo pacman $*
    fi
}

function end_part {
    echo "Installation des packet de base"
    pacstrap /mnt base base-devel pacman-contrib linux-firmware nano vim dhcpcd dhclient networkmanager grub os-prober efibootmgr zip unzip p7zip alsa-utils syslog-ng mtools dosfstools lsb-release ntfs-3g exfat-utils bash-completion ;

    echo "Génération du fstab"
    genfstab -U -p /mnt > /mnt/etc/fstab ;

    echo "Vérification du démarrage sécurisé EFI"
    efibootmgr | grep "EFI"
    if [ $1 == "efibootmgr | grep 'EFI'" ]
    then 
        $if_efi=true
    else
        $if_efi=false
    fi
    if [ $if_efi == false ]
    then
        echo "Installation des packet de grub pour bios"
        touch /mnt/home/arch_script_installer/bios_present ;
        pacstrap /mnt grub os-prober ;
    else
        echo "Installation des packet de grub pour efi"
        pacstrap /mnt grub os-prober efibootmgr ;
    fi

    echo "Ouverture du arch-chroot"
    arch-chroot /mnt ;
}

function in_arch_chroot {
    echo "Ajout de la lange francaise du clavier et du fuseau horaire"
    echo "KEYMAP=fr-latin9" >  "/etc/vconsole.conf" ;
    echo "FONT=eurlatgr"    >> "/etc/vconsole.conf" ;
    echo "LANG=fr_FR.UTF-8" >  "/etc/locale.conf"   ;
    echo "LC_COLLATE=C"     >> "/etc/locale.conf"   ;
    locale-gen ;
    export LANG=fr_FR.UTF-8 ;
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime ;
    hwclock --systohc --utc ;

    echo "Ajouts de MultiLib"
    sed -i 's/\#\[multilib\]/\[multilib\]/g' /etc/pacman.conf ;
    sed -i 's/\#Include \= \/etc\/pacman.d\/mirrorlist/Include \= \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf ;

    read -p "Voulez vous installer le Chaotic-AUR [O/n]: " $chaotic_aur
    if [ $chaotic_aur == "n" ]
    then
        pacman -Syyu
    else
        touch /home/arch_script_installer/chaotic_aur
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        pacman-key --lsign-key 3056513887B78AEB
        pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo "[chaotic-aur]" >> "/etc/pacman.conf"
        echo "Include = /etc/pacman.d/chaotic-mirrorlist" >> "/etc/pacman.conf"
        pacman -S powerpill
        pacman -Syy && powerpill -Su && paru -Su
    fi

    if [ -e /home/arch_script_installer/chaotic_aur ]
    then
        read -p "Voulez le karnel Clasique[c], Zen[Z], TKG-PDS (Gaming)[t] ou LTS[l]: " $karnel_type
    else
        read -p "Voulez le karnel Clasique[c], Zen[Z] ou LTS[l]: " $karnel_type
    fi
    echo ""
    if [ $karnel_type == "c" ]
    then
        echo "Installation du karnel Linux"
        packet_install -S linux-zen linux-zen-headers
        mkinitcpio -p linux-zen
    elif [ $karnel_type == "l" ]
    then
        echo "Installation du karnel Linux-LTS"
        packet_install -S linux-lts linux-lts-headers
        mkinitcpio -p linux-lts
    elif [ -e /home/arch_script_installer/chaotic_aur ]
    then
        echo "Installation du karnel Linux-TKG-PDS (Gaming)"
        if [ $karnel_type == "t" ]
        then
            packet_install -S linux-tkg-pds linux-tkg-pds-headers
        fi
    else
        echo "Installation du karnel Linux-Zen"
        packet_install -S linux linux-headers
        mkinitcpio -p linux
    fi

    if [ -e /home/arch_script_installer/bios_present ]
    then
        echo "Installation de grub pour bios"
        grub-install --no-floppy --recheck /dev/sda
    else
        echo "Installation de grub pour efi"
        mount | grep efivars &> /dev/null || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck
        mkdir /boot/efi/EFI/boot
        cp /boot/efi/EFI/arch_grub/grubx64.efi /boot/efi/EFI/boot/bootx64.efi
    fi

    echo "Génération de la configuration de grub"
    grub-mkconfig -o /boot/grub/grub.cfg

    echo "chengement du mots de passe root"
    passwd root

    echo "Installation de NetworkManager"
    packet_install -S networkmanager
    systemctl enable NetworkManager

    echo "Installation de NTP et Cronie"
    packet_install -S ntp cronie

    echo "ajout des log en claire"
    sed -i -r 's/\#ForwardToSyslog\=no/ForwardToSyslog\=no/g' /etc/systemd/journald.conf ;
    cat /etc/systemd/journald.conf | grep "ForwardToSyslog\=no" ;
    

    echo "Installation des greffons gstreamer"
    packet_install -S gst-plugins-{base,good,bad,ugly} gst-libav

    echo "Installation de xorg et de libinput"
    packet_install -S xorg-{server,xinit,apps} libinput xdg-user-dirs

    read -p "Votre carte grafique est une AMD[A], Intel[i], Nvidia[n] ou VM[v]: " $grafique_card
    echo ""
    if [ $grafique_card == "n" ]
    then
        read -p "Voulez vous les pilote libre ou propriétaire [o/N]: " $nvidia_lib
        echo ""
        if [ $nvidia_lib == "o" ]
        then
            echo "Installation des pilote nvidia libre"
            packet_install -S xf86-video-nouveau
        else
            echo "Installation des pilote nvidia propriétaire"
            packet_install -S nvidia
        fi
    elif [ $grafique_card == "i" ]
    then
        echo "Installation des pilote intel libre"
        packet_install -S xf86-video-intel
    elif [ $grafique_card == "v" ]
    then
        echo "Installation des pilote VM libre"
        packet_install -S ttf-{bitstream-vera,liberation,freefont,dejavu} freetype2
        packet_install -S xf86-video-vesa
        packet_install -S virtualbox-guest-utils
        systemctl enable vboxservice
    else
        echo "Installation des pilote amd libre"
        packet_install -S xf86-video-ati
    fi

    echo "Installation des packet pour les inprimante, les scanner et les gui"
    packet_install -S cups gimp gimp-help-fr hplip python-pyqt5
    packet_install -S foomatic-{db,db-ppds,db-gutenprint-ppds,db-nonfree,db-nonfree-ppds} gutenprint

    echo "Installation de libre office still"
    packet_install -S libreoffice-still-fr hunspell-fr

    echo "Installation de firefox et ublock"
    packet_install -S firefox-i18n-fr firefox-ublock-origin

    echo "ajout d'un nouvel utilisateur"
    while [ true ]
        read -p "Votre nom complet d'utilisateur" $user_name
        read -p "Votre nom machine d'utilisateur" $machine_user_name
        useradd -m -g wheel -c "$user_name" -s /bin/bash $machine_user_name
        passwd $machine_user_name
        read -p "Les information vous vont [O/n]: " $user_verif
        echo ""
        if [ $user_verif == "n" ]
        then
            userdel $machine_user_name
        else
            read -p "Voulez vous ajouter un autre utilisateur [o/N]: " $add_user
            echo ""
            if [ $add_user == "o" ]
            then
                echo "ajout d'un nouvel utilisateur"
            else
                break
            fi
        fi
    sed -i -r 's/\# \%wheel ALL\=\(ALL\) ALL/\%wheel ALL\=\(ALL\) ALL/g' /etc/sudoers ;
    cat /etc/sudoers | grep "\%wheel ALL\=(ALL) ALL" ;

    echo "Activation des service indispensable (heur, bluetooth, etc)"
    systemctl enable syslog-ng@default
    systemctl enable cronie
    systemctl enable avahi-daemon
    systemctl enable avahi-dnsconfd
    systemctl enable org.cups.cupsd
    systemctl enable bluetooth
    systemctl enable ntpd

    echo "Installation de l'interface grafique"
    read -p "Voulez vous gnome[g] ou xfce[X]: " $ui_type
    if [ $ui_type == "g" ]
    then
        echo "Installation de gnome"
        packet_install -S gdm gnome-shell gnome gnome-extra system-config-printer telepathy shotwell rhythmbox gnome-tweaks
        systemctl enable gdm.service
    else
        echo "Installation de xfce"
        packet_install -S xfce4 xfce4-goodies gvfs vlc quodlibet python-pyinotify lightdm-gtk-greeter xarchiver claws-mail galculator evince ffmpegthumbnailer xscreensaver pavucontrol pulseaudio-{alsa,bluetooth} blueman libcanberra-{pulse,gstreamer} system-config-printer network-manager-applet lightdm-gtk-greeter-settings
        touch /home/arch_script_installer/xfce_present
        systemctl enable lightdm.service

        echo "Installation de Docklike Taskbar for XFCE"
        git clone https://github.com/nsz32/docklike-plugin && cd docklike-plugin
        ./autogen.sh
        make
        sudo make install
    fi
    localectl set-x11-keymap fr

    sudo cp service/.xorg /home/$machine_user_name/

    read -p "Voulez vous installer wine [O/n]: " $if_wine
    if [ $if_wine != "n" ]
    then
        if [ -e /home/arch_script_installer/chaotic_aur ]
        then
            read -P "Voulez vous wine clasique[c] ou wine gaming(TKG-PDS)[T]: " $wine_version
        else
            wine_version="c"
        fi
        if [ $wine_version == "c" ]
        then
            echo "Installation de wine clasique"
            packet_install -S wine
        else
            echo "Installation de wine gaming"
            packet_install -S wine-tkg-staging-fsync-git
        fi
    fi

    echo "vous pouvez exit umount et reboot"
}

function on_user {
    if [ -e /home/arch_script_installer/xfce_present ]
    then
        echo "Activation des greffon pour Wifi, RJ45 et bluetooth"
        sudo cp service/{nm-applet.service,blueman-applet.service} /usr/lib/systemd/user/
        systemctl --user enable --now nm-applet.service
        systemctl --user enable --now blueman-applet.service
    fi

    read -p "Voulez vous installer fish (alternative conviviale a bash) [N/o]: " $if_fish
    echo ""
    if [ $if_fish == "o" ]
    then
        echo "Installation de fish"
        packet_install -S fish
        chsh /bin/fish
    fi

    read -p "Vouler vous installer AUR [O/n]: " $if_aur
        echo ""
    if [ $if_aur != "n" ]
    then
        echo "Installation de AUR avec yay"
        packet_install -S git
        git clone https://aur.archlinux.org/yay
        cd yay
        makepkg -sri
        cd ..
        rm -Rf yay
    fi

    read -p "Voulez vous installer gamemode [O/n]: " $if_gamemode
    if [ $if_gamemode != "n" ]
    then
    echo "Installation de gamemode"
        packet_install -S gamemode
        systemctl --user enable --now gamemoded.service
    fi

    read -p "Voulez vous installer Desktop Arch Update Indicator [O/n]: " $if_desktop_arch_update_indicator
    if [ $if_desktop_arch_update_indicator != "n" ]
    then
        echo "Installation de Desktop Arch Update Indicator"
        git clone https://github.com/Pikatsuto/desktop_arch_update_indicator.git
        cd desktop_arch_update_indicator
        bash install_desktop_arch_update_indicator.sh
    fi

    rm -Rf $USER/.xorg
}

function menu {
    echo "test"
}

if [ $1 == "--end_part" ]
then
    end_part
elif [ $1 == "--in_arch_chroot" ]
then
    in_arch_chroot
elif [ $1 == "--on_user" ]
then
    on_user
else
    menu
fi