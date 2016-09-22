# VSC Docker container

This container launches VSC VM using KVM and attaches its net devices to the DockerHost bridge devices brlol0 and brlol1.

## Build instructions

* Build docker-kvm container (also in this repository).
* Build container:

  ```
  $ docker build -t vsc .
  ```

## Run instructions

  ```
  docker run --privileged vsc -v /dev/pts:/dev/pts
  ```
