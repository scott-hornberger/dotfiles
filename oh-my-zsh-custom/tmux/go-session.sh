#!/bin/bash

go_session="go"
tmux new-session -d -s $go_session

tmux rename-window -t $go_session:1 'Main'
tmux send-keys -t $go_session:1 'cd $sparse' C-m

tmux new-window -t $go_session:2 -n 'Second'
tmux send-keys -t $go_session:2 'cd $sparse' C-m

echo "go session started"

