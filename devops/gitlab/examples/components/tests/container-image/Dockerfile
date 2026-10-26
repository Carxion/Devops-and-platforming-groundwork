# A minimal image to test the container-image component: a pinned base, a RUN
# step (which exercises Buildah's isolation), and a non-root user.
FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a
RUN echo "component test" > /message
USER 65534:65534
ENTRYPOINT ["cat", "/message"]
