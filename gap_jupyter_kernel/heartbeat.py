"""Serve heartbeat requests independently of GAP, until its lifetime pipe closes."""

import json
import os
import sys

import zmq


def run(connection_file, lifetime_fd, ready_fd):
    with open(connection_file, encoding="utf-8") as stream:
        config = json.load(stream)
    context = zmq.Context()
    socket = context.socket(zmq.REP)
    socket.linger = 0
    try:
        socket.bind(f"{config['transport']}://{config['ip']}:{config['hb_port']}")
        poller = zmq.Poller()
        poller.register(socket, zmq.POLLIN)
        poller.register(lifetime_fd, zmq.POLLIN)
        os.write(ready_fd, b"1")
        os.close(ready_fd)
        while True:
            events = dict(poller.poll())
            if lifetime_fd in events and os.read(lifetime_fd, 1) == b"":
                return
            if socket in events:
                socket.send_multipart(socket.recv_multipart())
    finally:
        socket.close()
        context.term()
        os.close(lifetime_fd)


if __name__ == "__main__":
    run(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
