#!/bin/bash

session="server"
tmux new-session -d -s $session

tmux rename-window -t $session:0 'cerberus'
tmux send-keys -t $session:0 'cdupf && cerberus' C-m

tmux new-window -t $session:1 -n 'jz dv'
tmux send-keys -t $session:1 'cdupf && UBER_RUNTIME_ENVIRONMENT=production jz dv' C-m

echo "server created"
