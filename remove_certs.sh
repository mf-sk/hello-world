#/bin/sh

# Vytvoríme zálohovací adresár, ak neexistuje
mkdir -p /tmp/zaloha
cd /your/folder/certificates
touch  cert_remove_report.txt 

# Nájdeme certifikáty, skontrolujeme ich platnosť a ak sú expirované, zálohujeme a vymažeme (.p12 a .jks vyžadujú každý iné heslo)
find /your/folder/certificates -name "*.crt" -o -name "*.pem" -o -name "*.cer" 2>/dev/null | while read cert; do
    if openssl x509 -checkend 0 -noout -in "$cert" 2>/dev/null; then
        echo "Platný certifikát: $cert" >> cert_remove_report.txt 
    else
        echo "Expirovaný certifikát: $cert" >> cert_remove_report.txt
        
        # Zálohujeme expirovaný certifikát
        cp "$cert" /tmp/zaloha/
        
        # Odstránime expirovaný certifikát z filesystemu
        rm -f "$cert"
        
        echo "Certifikát $cert bol zálohovaný a odstránený." >> cert_remove_report.txt
    fi
done

## Funkcie pre .p12 a .jks ak vieme heslo:

# Funkcia pre kontrolu a zálohu .jks úložísk
check_jks() {
    keystore=$1
    # Zadajte heslo pre JKS úložiská (zmeniť podľa potreby)
    password="heslo"
    
    # Získame zoznam certifikátov v JKS úložisku
    for alias in $(keytool -list -keystore "$keystore" -storepass "$password" | grep ", " | awk '{print $1}'); do
        # Skontrolujeme expiráciu certifikátu
        if keytool -keystore "$keystore" -storepass "$password" -list -v -alias "$alias" | grep -q 'valid from'; then
            echo "Platný certifikát v úložisku $keystore, alias: $alias"
        else
            echo "Expirovaný certifikát v úložisku $keystore, alias: $alias"
            cp "$keystore" /tmp/zaloha/
            rm -f "$keystore"
            echo "Úložisko $keystore bolo zálohované a odstránené."
            break
        fi
    done
}

# Funkcia pre kontrolu a zálohu .p12 a .pfx úložísk
check_p12_pfx() {
    keystore=$1
    # Zadajte heslo pre P12/PFX úložiská (zmeniť podľa potreby)
    password="heslo"

    # Extrahujeme certifikáty z úložiska a skontrolujeme ich
    openssl pkcs12 -in "$keystore" -nokeys -passin pass:"$password" | \
    openssl x509 -checkend 0 -noout 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Expirovaný certifikát v úložisku: $keystore"
        cp "$keystore" /tmp/zaloha/
        rm -f "$keystore"
        echo "Úložisko $keystore bolo zálohované a odstránené."
    else
        echo "Platný certifikát v úložisku: $keystore"
    fi
}
