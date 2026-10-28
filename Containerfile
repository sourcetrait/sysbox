FROM registry.fedoraproject.org/fedora:latest
USER root
WORKDIR /root
RUN --mount=type=bind,source=dist,target=/mnt/dist/fedora,Z bash /mnt/dist/install/package.bash
RUN --mount=type=bind,source=dist,target=/mnt/dist/fedora,Z bash /mnt/dist/install/root.bash
USER box
WORKDIR /home/box
RUN --mount=type=bind,source=dist,target=/mnt/dist/fedora,Z bash /mnt/dist/install/box.bash
USER root
WORKDIR /root
CMD ["/sbin/init"]
