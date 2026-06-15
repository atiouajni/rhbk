# Déploiement Keycloak avec PostgreSQL sur OpenShift

## Versions testées
- OpenShift: 4.21.6
- RHBK Operator: 26.4.12-opr.1
- PostgreSQL: 15

## Prérequis
- OpenShift CLI (`oc`)
- `envsubst` (disponible via le package `gettext`)
- Accès à un cluster OpenShift

## Structure du projet

```
.
├── base/
│   ├── kustomization.yaml          # Configuration Kustomize
│   ├── keycloak-instance.yaml      # Instance Keycloak
│   ├── keycloak-route.yaml         # Route OpenShift
│   └── postgresl-db-statefulset.yaml  # PostgreSQL + Secret
├── .env.example                    # Template variables d'environnement
├── install.sh                      # Script d'installation
└── README.md                       # Ce fichier
```

## Installation

### Étape 1 : Créer le namespace et installer l'opérateur

```bash
# 1. Créer le namespace
oc new-project rhbk-demo

# 2. Installer l'opérateur RHBK depuis OperatorHub
# Via la console OpenShift:
#   - Operators > OperatorHub
#   - Chercher "Red Hat build of Keycloak"
#   - Installer dans le namespace "rhbk-demo"

# 3. Attendre que l'opérateur soit prêt
oc get csv -n rhbk-demo -w
```

### Étape 2 : Configurer les variables

1. Copier le fichier d'environnement :
```bash
cp .env.example .env
```

2. Modifier les valeurs dans `.env` selon votre environnement :
```bash
export NAMESPACE=rhbk-demo
export CLUSTER_APPS_DOMAIN=apps.sno4.anissetiouajni.com
```

### Étape 3 : Déployer Keycloak

#### Avec le script d'installation (recommandé)
```bash
./install.sh
```

Le script va :
- Vérifier les prérequis (namespace, opérateur)
- Déployer PostgreSQL et Keycloak
- Attendre que les pods soient prêts
- Afficher l'URL d'accès

#### Installation manuelle

```bash
# 1. Charger les variables
source .env

# 2. Déployer
oc kustomize ./base | envsubst | oc apply -f -

# 3. Vérifier
oc get pods -n ${NAMESPACE}
```

## Vérification du déploiement

```bash
source .env

# Vérifier les pods
oc get pods -n ${NAMESPACE}

# Vérifier la route
oc get route -n ${NAMESPACE}

# Voir les logs Keycloak
oc logs -f deployment/kc -n ${NAMESPACE}

# Voir les logs PostgreSQL
oc logs -f statefulset/postgresql-db -n ${NAMESPACE}
```

## Accès à Keycloak

```bash
source .env
echo "https://kc-${NAMESPACE}.${CLUSTER_APPS_DOMAIN}"
```

URL par défaut : https://kc-rhbk-demo.apps.sno4.anissetiouajni.com

## Ressources déployées

- **PostgreSQL** : Base de données pour Keycloak (StatefulSet)
- **Secret** : Credentials PostgreSQL (user: keycloak, password: keycloak123)
- **Keycloak** : Instance Keycloak avec 1 réplica connectée à PostgreSQL
- **Route** : Exposition HTTPS avec TLS edge termination

## Credentials par défaut

### PostgreSQL
- User: `keycloak`
- Password: `keycloak123`
- Database: `keycloak`

### Keycloak Admin
Les credentials admin sont générés automatiquement par l'operator.
Pour les récupérer :
```bash
oc get secret kc-initial-admin -n ${NAMESPACE} -o jsonpath='{.data.username}' | base64 -d && echo
oc get secret kc-initial-admin -n ${NAMESPACE} -o jsonpath='{.data.password}' | base64 -d && echo
```

## Configuration Keycloak

### Importer un Realm depuis un fichier JSON

Pour importer un realm Keycloak (par exemple pour RHDH ou d'autres applications) :

**Via la console d'administration :**

1. Connectez-vous à la console admin Keycloak avec les credentials récupérés ci-dessus
2. Dans le menu déroulant des realms (en haut à gauche), cliquez sur **"Create Realm"**
3. Cliquez sur **"Browse"** pour sélectionner votre fichier `realm.json`
4. Cliquez sur **"Create"**

Le realm sera importé avec tous ses clients, utilisateurs, rôles et configurations.

**Documentation officielle :**
- [Keycloak Import/Export](https://www.keycloak.org/server/importExport#_importing_and_exporting_by_using_the_admin_console)

**Exemple de realms pré-configurés :**
- Pour RHDH : voir le repo [rhdh](https://github.com/atiouajni/rhdh) qui contient `keycloak-rhdh-realm-simple.json`

## Troubleshooting

### Keycloak ne démarre pas
```bash
# Vérifier les logs
oc logs -f deployment/kc -n ${NAMESPACE}

# Vérifier que PostgreSQL est prêt
oc get pods -n ${NAMESPACE} | grep postgres
```

### Problème de connexion à la base de données
```bash
# Vérifier le secret
oc get secret postgres-secret -n ${NAMESPACE} -o yaml

# Tester la connexion depuis Keycloak
oc exec -it deployment/kc -n ${NAMESPACE} -- curl postgres-db:5432
```
