# argocd-helmfile-plugin

[![CI Pipeline](https://github.com/logica0419/argocd-helmfile-plugin/actions/workflows/ci.yaml/badge.svg)](https://github.com/logica0419/argocd-helmfile-plugin/actions/workflows/ci.yaml)
[![License](https://img.shields.io/github/license/logica0419/argocd-helmfile-plugin.svg)](https://github.com/logica0419/argocd-helmfile-plugin/blob/main/LICENSE)
[![Current Release](https://img.shields.io/github/release/logica0419/argocd-helmfile-plugin.svg?logo=github)](https://github.com/logica0419/argocd-helmfile-plugin/releases/latest)

Argo CD CMP (Config Management Plugin) for Helmfile

## Installation

### Without encryption

If you don't use [helm-secrets](https://github.com/jkroepke/helm-secrets) to encrypt the values files, you can install Argo CD with this CMP as follows.

1. **Create the values file**

    ```yaml
    repoServer:
      extraContainers:
        - name: helmfile-plugin
          image: ghcr.io/logica0419/argocd-helmfile-plugin:latest
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
          volumeMounts:
            - mountPath: /var/run/argocd
              name: var-files
            - mountPath: /home/argocd/cmp-server/plugins
              name: plugins
    ```

2. **Install Argo CD with [Helm](https://helm.sh/)**

    ```sh
    helm repo add argo https://argoproj.github.io/argo-helm
    helm upgrade --install --create-namespace -n argocd argocd argo/argo-cd -f values.yaml
    ```

### With encryption

If you want to encrypt the values files with [helm-secrets](https://github.com/jkroepke/helm-secrets), follow the steps below.

1. **Check the prerequisites**

   - [SOPS](https://github.com/getsops/sops)
     - The backend of helm-secret
   - [age](https://github.com/FiloSottile/age)
     - Used for encryption from SOPS

2. **Create the private key & secret**

    First, create a private key for encrypting with [age](https://github.com/FiloSottile/age):

    ```sh
    age-keygen -o keys.txt
    ```

    Then, create a Kubernetes secret from this key:

    ```sh
    kubectl -n argocd create secret generic age --from-file=key.txt
    ```

3. **Install Argo CD**

    Create the values file:

    ```yaml
    repoServer:
      volumes:
        - name: age
          secret:
            secretName: age

      extraContainers:
        - name: helmfile-plugin
          image: ghcr.io/logica0419/argocd-helmfile-plugin:latest
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
          env:
            - name: SOPS_AGE_KEY_FILE
              value: /app/config/age/key.txt
          volumeMounts:
            - mountPath: /var/run/argocd
              name: var-files
            - mountPath: /home/argocd/cmp-server/plugins
              name: plugins
            - mountPath: /app/config/age/
              name: age
    ```

    Finally, install Argo CD with [Helm](https://helm.sh/docs/intro/install/):

    ```sh
    helm repo add argo https://argoproj.github.io/argo-helm
    helm upgrade --install --create-namespace -n argocd argocd argo/argo-cd -f values.yaml
    ```

## Usage

Create an application with the `helmfile.yaml` path and an empty object in the plugin field.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: example-application
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ YOUR_GIT_REPO_URL }}
    path: {{ YOUR_HELMFILE_PATH }}
    targetRevision: main
    plugin: {}
  destination:
    server: https://kubernetes.default.svc
    namespace: example
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated:
      prune: true
      selfHeal: true
```

### Environment Variables

This CMP has two environment variables.

| Name        | `ENV_NAME`                         | `ENABLE_LOOKUP`                                                                                                                                                 |
| ----------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description | The environment that Helmfile uses | Enable the ["lookup" function](https://helm.sh/docs/chart_template_guide/functions_and_pipelines/#using-the-lookup-function) in the helm chart (default: false) |

> NOTE 1: The **"lookup" function doesn't work with the "helmfile template"** (actually "helm template") command by default.  
> See [argoproj/argo-cd#5202](https://github.com/argoproj/argo-cd/issues/5202#issuecomment-2040122017).
>
> NOTE 2: You must provide the **appropriate Role or ClusterRole to the repo-server** to look up the resources with the "lookup" function.

You can configure them in the application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: example-application
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ YOUR_GIT_REPO_URL }}
    path: {{ YOUR_HELMFILE_PATH }}
    targetRevision: main
    plugin:
      env:
        - name: ENABLE_LOOKUP
          value: "true"
        - name: ENV_NAME
          value: development
  destination:
    server: https://kubernetes.default.svc
    namespace: example
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated:
      prune: true
      selfHeal: true
```

Or in the Argo CD values file:

```yaml
repoServer:
  extraContainers:
    - name: helmfile-plugin
      image: ghcr.io/logica0419/argocd-helmfile-plugin:latest
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
      volumeMounts:
        - mountPath: /var/run/argocd
          name: var-files
        - mountPath: /home/argocd/cmp-server/plugins
          name: plugins
      env:
        - name: ENABLE_LOOKUP
          value: "true"
        - name: ENV_NAME
          value: development

  clusterRoleRules:
    enabled: true
    rules:
      - apiGroups: [""]
        resources:
          - configmaps
          - secrets
        verbs:
          - get
```

### Encryption

Please read the [helm-secrets](https://github.com/jkroepke/helm-secrets/wiki/Usage) documentation to encrypt secrets or values files.

## Why the new Helmfile CMP?

The Argo CD CMPs for Helmfile already exist.

- <https://github.com/lucj/argocd-helmfile-plugin>
- <https://github.com/travisghansen/argo-cd-helmfile>

Of course, they influenced this CMP so much.

However, these CMPs have some problems:

- The enormous amount of **dependencies**
  - Helmfile has many dependencies, and these CMPs install them in the Dockerfile.
  - This requires active & frequent maintenance and upgrade.
- The **complexity** of the codes & functionalities
  - The codes are complex due to the dependencies and functionalities, making them hard to maintain.
  - The too many customizable features make it hard to understand.
- The lack of the **"lookup" function** support
  - The "lookup" function is a powerful feature in the Helm chart, but these CMPs don't support it.

This CMP solves these problems:

- Based on the **Helmfile official Docker image**
  - It realizes the single dependency, making it easy to maintain.
  - It also enables the auto version determination & upgrade.
- The **Simple & minimal codes and functionalities**
  - The customizable settings are only `ENV_NAME` and `ENABLE_LOOKUP`.
  - It has a short code length, making it much more readable.
- The **"lookup" function** support
