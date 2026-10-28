FROM registry.fedoraproject.org/fedora:latest
RUN --mount=type=bind,source=dist,target=/mnt/dist,Z bash /mnt/dist/setup.bash
CMD ["/sbin/init"]
