# k3s/lib.nix — Helper functions for generating K8s manifests as Nix attrsets
{
  lib,
  fullDomain,
}: let
  # Convert an attrset of env vars to K8s env list format
  mkEnvList = envAttrs:
    lib.mapAttrsToList (name: value: {
      inherit name;
      value = toString value;
    })
    envAttrs;

  # Convert volume shorthand to K8s volume + volumeMount pairs
  mkVolumePair = vol: {
    volume =
      {name = vol.name;}
      // (
        if vol ? hostPath
        then {hostPath.path = vol.hostPath;}
        else if vol ? pvc
        then {persistentVolumeClaim.claimName = vol.pvc;}
        else if vol ? configMap
        then {configMap.name = vol.configMap;}
        else if vol ? emptyDir
        then {emptyDir = vol.emptyDir;}
        else {}
      );
    mount =
      {
        name = vol.name;
        mountPath = vol.mountPath;
      }
      // lib.optionalAttrs (vol ? readOnly && vol.readOnly) {readOnly = true;}
      // lib.optionalAttrs (vol ? subPath) {subPath = vol.subPath;};
  };
in {
  # Wrap multiple K8s resources into a single List manifest
  mkList = items: {
    apiVersion = "v1";
    kind = "List";
    inherit items;
  };

  # Standard Deployment resource
  mkDeployment = {
    name,
    image,
    port ? null,
    ports ? [],
    namespace ? "default",
    replicas ? 1,
    env ? {},
    envFrom ? [],
    args ? [],
    command ? [],
    volumes ? [],
    securityContext ? {},
    containerSecurityContext ? {},
    resources ? {},
    labels ? {},
    annotations ? {},
    podAnnotations ? {},
    affinity ? {},
    nodeSelector ? {},
    tolerations ? [],
    initContainers ? [],
    extraContainers ? [],
    strategy ? {},
    dnsPolicy ? null,
    hostNetwork ? false,
    imagePullPolicy ? null,
    livenessProbe ? null,
    readinessProbe ? null,
    envVars ? [],
    imagePullSecrets ? [],
  }: let
    volumePairs = map mkVolumePair volumes;
    allPorts =
      if port != null
      then [
        {
          containerPort = port;
          name = "http";
        }
      ]
      else
        map (p:
          {containerPort = p.containerPort;}
          // lib.optionalAttrs (p ? name) {name = p.name;}
          // lib.optionalAttrs (p ? protocol) {protocol = p.protocol;})
        ports;
    envList = mkEnvList env ++ envVars;
  in {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata =
      {
        inherit name namespace;
      }
      // lib.optionalAttrs (labels != {}) {inherit labels;}
      // lib.optionalAttrs (annotations != {}) {inherit annotations;};
    spec =
      {
        inherit replicas;
        selector.matchLabels.app = name;
        template = {
          metadata =
            {
              labels =
                {app = name;}
                // labels;
            }
            // lib.optionalAttrs (podAnnotations != {}) {annotations = podAnnotations;};
          spec =
            {
              containers =
                [
                  ({
                      inherit name image;
                    }
                    // lib.optionalAttrs (imagePullPolicy != null) {inherit imagePullPolicy;}
                    // lib.optionalAttrs (allPorts != []) {ports = allPorts;}
                    // lib.optionalAttrs (envList != []) {env = envList;}
                    // lib.optionalAttrs (envFrom != []) {inherit envFrom;}
                    // lib.optionalAttrs (args != []) {inherit args;}
                    // lib.optionalAttrs (command != []) {inherit command;}
                    // lib.optionalAttrs (volumePairs != []) {
                      volumeMounts = map (vp: vp.mount) volumePairs;
                    }
                    // lib.optionalAttrs (resources != {}) {inherit resources;}
                    // lib.optionalAttrs (containerSecurityContext != {}) {securityContext = containerSecurityContext;}
                    // lib.optionalAttrs (livenessProbe != null) {inherit livenessProbe;}
                    // lib.optionalAttrs (readinessProbe != null) {inherit readinessProbe;})
                ]
                ++ extraContainers;
            }
            // lib.optionalAttrs (initContainers != []) {inherit initContainers;}
            // lib.optionalAttrs (securityContext != {}) {inherit securityContext;}
            // lib.optionalAttrs (volumePairs != []) {
              volumes = map (vp: vp.volume) volumePairs;
            }
            // lib.optionalAttrs (affinity != {}) {inherit affinity;}
            // lib.optionalAttrs (nodeSelector != {}) {inherit nodeSelector;}
            // lib.optionalAttrs (tolerations != []) {inherit tolerations;}
            // lib.optionalAttrs (imagePullSecrets != []) {inherit imagePullSecrets;}
            // lib.optionalAttrs (dnsPolicy != null) {inherit dnsPolicy;}
            // lib.optionalAttrs hostNetwork {inherit hostNetwork;};
        };
      }
      // lib.optionalAttrs (strategy != {}) {inherit strategy;};
  };

  # NodePort Service resource
  mkNodePortService = {
    name,
    port,
    nodePort,
    targetPort ? port,
    namespace ? "default",
    labels ? {},
  }: {
    apiVersion = "v1";
    kind = "Service";
    metadata =
      {
        inherit name namespace;
      }
      // lib.optionalAttrs (labels != {}) {inherit labels;};
    spec = {
      type = "NodePort";
      selector.app = name;
      ports = [
        {
          inherit port targetPort nodePort;
        }
      ];
    };
  };

  # ClusterIP Service resource
  mkClusterIPService = {
    name,
    port,
    targetPort ? port,
    namespace ? "default",
    labels ? {},
  }: {
    apiVersion = "v1";
    kind = "Service";
    metadata =
      {
        inherit name namespace;
      }
      // lib.optionalAttrs (labels != {}) {inherit labels;};
    spec = {
      type = "ClusterIP";
      selector.app = name;
      ports = [
        {
          inherit port targetPort;
        }
      ];
    };
  };

  # PersistentVolumeClaim resource
  mkPvc = {
    name,
    storage ? "1Gi",
    storageClassName ? "local-path",
    accessModes ? ["ReadWriteOnce"],
    namespace ? "default",
    labels ? {},
    volumeName ? null,
  }: {
    apiVersion = "v1";
    kind = "PersistentVolumeClaim";
    metadata =
      {
        inherit name namespace;
      }
      // lib.optionalAttrs (labels != {}) {inherit labels;};
    spec =
      {
        inherit accessModes;
        inherit storageClassName;
        resources.requests = {inherit storage;};
      }
      // lib.optionalAttrs (volumeName != null) {inherit volumeName;};
  };

  # PersistentVolume resource
  mkPv = {
    name,
    storage ? "1Gi",
    storageClassName ? "",
    accessModes ? ["ReadWriteOnce"],
    hostPath,
    hostPathType ? "DirectoryOrCreate",
    reclaimPolicy ? "Retain",
  }: {
    apiVersion = "v1";
    kind = "PersistentVolume";
    metadata = {inherit name;};
    spec = {
      capacity = {inherit storage;};
      inherit accessModes storageClassName;
      persistentVolumeReclaimPolicy = reclaimPolicy;
      hostPath = {
        path = hostPath;
        type = hostPathType;
      };
    };
  };

  # ConfigMap resource
  mkConfigMap = {
    name,
    namespace ? "default",
    data,
  }: {
    apiVersion = "v1";
    kind = "ConfigMap";
    metadata = {inherit name namespace;};
    inherit data;
  };

  # Secret resource
  mkSecret = {
    name,
    namespace ? "default",
    stringData ? {},
    type ? "Opaque",
  }: {
    apiVersion = "v1";
    kind = "Secret";
    metadata = {inherit name namespace;};
    inherit type stringData;
  };

  # Common wrapper for K8s secret injection services
  # Usage: mkSecretService { inherit pkgs; } { name, description, secretArgs, checkVar }
  mkSecretService = {pkgs}: {
    name,
    description,
    secretArgs,
    checkVar,
  }: {
    systemd.services."${name}" = {
      inherit description;
      after = ["k3s.service"];
      requires = ["k3s.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript name ''
          #!/bin/sh
          set -e

          # Wait for K3s to be ready
          sleep 10

          # Use k3s kubectl
          KUBECTL="/run/current-system/sw/bin/k3s kubectl"
          if ! $KUBECTL version &>/dev/null 2>&1; then
            echo "k3s kubectl not ready yet, skipping..."
            exit 0
          fi

          ${secretArgs}

          echo "${name} updated successfully"
        ''}";
      };
    };

    systemd.timers."${name}" = {
      description = "Timer to refresh ${name}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1h";
        Unit = "${name}.service";
      };
    };
  };

  # PodDisruptionBudget resource
  mkPdb = {
    name,
    appName,
    minAvailable ? 1,
    namespace ? "default",
  }: {
    apiVersion = "policy/v1";
    kind = "PodDisruptionBudget";
    metadata = {inherit name namespace;};
    spec = {
      inherit minAvailable;
      selector.matchLabels.app = appName;
    };
  };

  # Ingress resource with homepage annotations support
  mkIngress = {
    name,
    subdomain ? name,
    port,
    serviceName ? name,
    namespace ? "default",
    tlsSecret ? "traefik-tls-secret",
    homepage ? {},
    extraAnnotations ? {},
  }: {
    apiVersion = "networking.k8s.io/v1";
    kind = "Ingress";
    metadata = {
      name = "${name}-ingress";
      inherit namespace;
      annotations =
        {
          "kubernetes.io/ingress.class" = "traefik";
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure";
        }
        // lib.optionalAttrs (homepage != {}) (
          {
            "gethomepage.dev/enabled" = "true";
          }
          // lib.optionalAttrs (homepage ? name) {"gethomepage.dev/name" = homepage.name;}
          // lib.optionalAttrs (homepage ? group) {"gethomepage.dev/group" = homepage.group;}
          // lib.optionalAttrs (homepage ? description) {"gethomepage.dev/description" = homepage.description;}
          // lib.optionalAttrs (homepage ? icon) {"gethomepage.dev/icon" = homepage.icon;}
          // lib.optionalAttrs (homepage ? podSelector) {"gethomepage.dev/pod-selector" = homepage.podSelector;}
          // lib.optionalAttrs (homepage ? weight) {"gethomepage.dev/weight" = homepage.weight;}
          // lib.optionalAttrs (homepage ? widget) (
            lib.optionalAttrs (homepage.widget ? type) {"gethomepage.dev/widget.type" = homepage.widget.type;}
            // lib.optionalAttrs (homepage.widget ? url) {"gethomepage.dev/widget.url" = homepage.widget.url;}
            // lib.optionalAttrs (homepage.widget ? key) {"gethomepage.dev/widget.key" = homepage.widget.key;}
            // lib.optionalAttrs (homepage.widget ? user) {"gethomepage.dev/widget.user" = homepage.widget.user;}
            // lib.optionalAttrs (homepage.widget ? token) {"gethomepage.dev/widget.token" = homepage.widget.token;}
            // lib.optionalAttrs (homepage.widget ? salt) {"gethomepage.dev/widget.salt" = homepage.widget.salt;}
            // lib.optionalAttrs (homepage.widget ? slug) {"gethomepage.dev/widget.slug" = homepage.widget.slug;}
            // lib.optionalAttrs (homepage.widget ? username) {"gethomepage.dev/widget.username" = homepage.widget.username;}
            // lib.optionalAttrs (homepage.widget ? password) {"gethomepage.dev/widget.password" = homepage.widget.password;}
            // lib.optionalAttrs (homepage.widget ? version) {"gethomepage.dev/widget.version" = homepage.widget.version;}
          )
        )
        // extraAnnotations;
    };
    spec = {
      rules = [
        {
          host = "${subdomain}.${fullDomain}";
          http.paths = [
            {
              path = "/";
              pathType = "Prefix";
              backend.service = {
                name = serviceName;
                port.number = port;
              };
            }
          ];
        }
      ];
      tls = [
        {
          secretName = tlsSecret;
          hosts = [fullDomain];
        }
      ];
    };
  };
}
