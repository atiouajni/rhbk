#!/bin/bash

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Vérifier les prérequis
info "Vérification des prérequis..."

command -v oc >/dev/null 2>&1 || error "oc CLI n'est pas installé"
command -v envsubst >/dev/null 2>&1 || error "envsubst n'est pas installé (installez le package gettext)"

# Vérifier que l'utilisateur est connecté à OpenShift
oc whoami >/dev/null 2>&1 || error "Vous n'êtes pas connecté à OpenShift. Utilisez 'oc login' d'abord."

# Charger les variables d'environnement
if [ ! -f .env ]; then
    warning "Le fichier .env n'existe pas. Utilisation de .env.example..."
    if [ ! -f .env.example ]; then
        error "Aucun fichier .env ou .env.example trouvé"
    fi
    cp .env.example .env
    warning "Fichier .env créé. Veuillez le modifier si nécessaire et relancer le script."
    exit 0
fi

info "Chargement des variables d'environnement depuis .env..."
source .env

# Vérifier que les variables sont définies
[ -z "$NAMESPACE" ] && error "NAMESPACE n'est pas défini dans .env"
[ -z "$CLUSTER_APPS_DOMAIN" ] && error "CLUSTER_APPS_DOMAIN n'est pas défini dans .env"

info "Configuration:"
echo "  - Namespace: $NAMESPACE"
echo "  - Domaine: $CLUSTER_APPS_DOMAIN"
echo "  - Hostname Keycloak: kc-${NAMESPACE}.${CLUSTER_APPS_DOMAIN}"

# Demander confirmation
read -p "Continuer avec cette configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Installation annulée"
    exit 0
fi

# Vérifier que le namespace existe
info "Vérification du namespace..."
if ! oc get project $NAMESPACE >/dev/null 2>&1; then
    error "Le namespace $NAMESPACE n'existe pas. Créez-le d'abord avec: oc new-project $NAMESPACE"
fi

# Vérifier que le Keycloak Operator est installé dans le namespace
info "Vérification de l'installation du Keycloak Operator dans le namespace $NAMESPACE..."
if ! oc get csv -n $NAMESPACE | grep -q rhbk-operator 2>/dev/null; then
    error "Le Keycloak Operator (RHBK) n'est pas installé dans le namespace $NAMESPACE. Installez-le depuis OperatorHub avant de continuer."
fi
info "✓ Keycloak Operator détecté"

# Déployer les ressources
info "Déploiement des ressources..."
oc kustomize ./base | envsubst | oc apply -f -

# Attendre que les pods soient prêts
info "Attente du démarrage de PostgreSQL..."
oc rollout status statefulset/postgresql-db -n $NAMESPACE --timeout=5m || warning "Timeout en attendant PostgreSQL"

info "Attente du démarrage de Keycloak..."
oc wait --for=condition=Ready keycloak/kc -n $NAMESPACE --timeout=10m || warning "Timeout en attendant Keycloak"

# Afficher le statut
info "Statut du déploiement:"
oc get pods -n $NAMESPACE

# Afficher l'URL d'accès
info ""
info "✅ Déploiement terminé avec succès!"
info ""
info "URL d'accès Keycloak: https://kc-${NAMESPACE}.${CLUSTER_APPS_DOMAIN}"
info ""
info "Commandes utiles:"
echo "  - Voir les logs Keycloak: oc logs -f deployment/kc -n $NAMESPACE"
echo "  - Voir les logs PostgreSQL: oc logs -f statefulset/postgresql-db -n $NAMESPACE"
echo "  - Voir les pods: oc get pods -n $NAMESPACE"
