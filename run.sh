#!/bin/bash

if [ "${ROOT_PASS}" == "**None**" ]; then
    unset ROOT_PASS
fi

if [ "${PUBLIC_HOST_ADDR}" == "**None**" ]; then
    unset PUBLIC_HOST_ADDR
fi

if [ "${PUBLIC_HOST_PORT}" == "**None**" ]; then
    unset PUBLIC_HOST_PORT
fi

if [ "${PROXY_PORT}" == "**None**" ]; then
    unset PROXY_PORT
fi

if [ "${PASSWORD_MODE}" == "**None**" ]; then
    unset PASSWORD_MODE
fi

SetRootPass()
{
    if [ -f /.root_pw_set ]; then
	    echo "Root password already set!"
    else
        PASS=${ROOT_PASS:-$(pwgen -s 12 1)}
        _word=$( [ ${ROOT_PASS} ] && echo "preset" || echo "random" )
        echo "=> Setting a ${_word} password to the root user"
        echo "root:$PASS" | chpasswd

        echo "=> Done!"
        touch /.root_pw_set

        echo "========================================================================"
        echo "You can now connect to this Ubuntu container via SSH using:"
        echo ""
        echo "    ssh -p <port> root@<host>"
        echo "and enter the root password '$PASS' when prompted"
        echo ""
        echo "Please remember to change the above password as soon as possible!"
        echo "========================================================================"
    fi
}

if [[ -n "${PUBLIC_HOST_ADDR}" && -n "${PUBLIC_HOST_PORT}" ]]; then
    echo "=> Running in NATed host mode"
    if [ -z "${PROXY_PORT}" ]; then
        echo "PROXY_PORT needs to be specified!"
    fi
    if [ -z "${ROOT_PASS}" ]; then
        echo "ROOT_PASS needs to be specified!"
    fi

    echo "=> Connecting to Remote SSH servier ${PUBLIC_HOST_ADDR}:${PUBLIC_HOST_PORT}"

    KNOWN_HOSTS="/root/.ssh/known_hosts"
    if [ !-f ${KNOWN_HOST} ]; then
        echo "=> Scaning and save fingerprint from the remote server ..."
        ssh-keyscan -p ${PUBLIC_HOST_PORT} -H ${PUBLIC_HOST_ADDR} > ${KNOWN_HOSTS}
        if [ $(stat -c %s ${KNOWN_HOSTS}) == "0" ]; then
            echo "=> cannot get fingerprint from remote server, exiting ..."
            exit 1
        fi
        else
        echo "=> Fingerprint of remote server found, skipping"
    fi
    echo "====REMOTE FINGERPRINT===="
    cat ${KNOWN_HOSTS}
    echo "====REMOTE FINGERPRINT===="
    localhostIP=$(/sbin/ip route|awk '/default/ { print $3 }')
    echo "hosts IP (according to /sbin/ip route) is: ${localhostIP}"
    echo "=> Setting up the reverse ssh tunnel"
    
    if [ ! -f /root/.ssh/id_rsa ]; then
	    echo "Generate key pair"
        ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" -q
    fi
    
    echo "Send public key to server"
    sshpass -p ${ROOT_PASS} ssh-copy-id root@${PUBLIC_HOST_ADDR} -p ${PUBLIC_HOST_PORT}
    echo "You have to restart the server if you want to enable only public key authentication"


    echo "=> Establish a connection to the server"
    while true
    do
        sshpass -p ${ROOT_PASS} autossh -M 0 -NgR 1080:${localhostIP}:${PROXY_PORT} root@${PUBLIC_HOST_ADDR} -p ${PUBLIC_HOST_PORT}
        echo "=> Tunnel Link down!"
        echo "=> Wait 15 seconds to reconnect"
        sleep 15
        echo "=> Reconnecting..."
    done
else
    echo "=> Running in public host mode"
    if [ ! -f /.root_pw_set ]; then
	    SetRootPass
    fi

    if [[ -f /root/.ssh/authorized_keys && ! -n "${PASSWORD_MODE}" ]]; then
        echo "Disable Password Authentication Mode"
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi

    exec /usr/sbin/sshd -D
fi
