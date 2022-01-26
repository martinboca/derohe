#!/usr/bin/env bash

#set -x   # to enable debug and verbose printing of each and every command

# this will test case if lottery can run within a block

CURDIR=`/bin/pwd`
BASEDIR=$(dirname $0)
ABSPATH=$(readlink -f $0)
ABSDIR=$(dirname $ABSPATH)

command -v curl >/dev/null 2>&1 || { echo "I require curl but it's not installed.  Aborting." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "I require jq but it's not installed.  Aborting." >&2; exit 1; }

baseasset="0000000000000000000000000000000000000000000000000000000000000000"

daemon_rpc_port="20000"  # daemon rpc is listening on this port

# we have number of wallets listening at ports from 30000
# we will be using 3 wallets, named owner, player1,player2
owner_rpc_port="30000"
player1_rpc_port="30001"
player2_rpc_port="30002"

owner_address=$(curl --silent http://127.0.0.1:$owner_rpc_port/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getaddress"}' -H 'Content-Type: application/json'| jq -r ".result.address")
player1_address=$(curl --silent http://127.0.0.1:$player1_rpc_port/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getaddress"}' -H 'Content-Type: application/json'| jq -r ".result.address")
player2_address=$(curl --silent http://127.0.0.1:$player2_rpc_port/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getaddress"}' -H 'Content-Type: application/json'| jq -r ".result.address")


function balance(){
  	curl --silent http://127.0.0.1:$1/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getbalance"}' -H 'Content-Type: application/json'| jq -r ".result.balance"
}

function scassetbalance(){
  	curl --silent http://127.0.0.1:$daemon_rpc_port/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getsc","params":{ "scid":"'"$1"'" , "code":false, "variables":true}}' -H 'Content-Type: application/json'| jq -r '.result.balances."'$2'"'
}

function mineblock(){
    touch /dev/shm/mineblocknow
}

echo "SC owner address" $owner_address
echo "player1 address" $player1_address
echo "player2 address" $player2_address


# use owner wallet to load/install an lotter sc to chain
scid=$(curl --silent --request POST --data-binary   @test.bas http://127.0.0.1:$owner_rpc_port/install_sc| jq -r ".txid")
echo "SCID" $scid
mineblock
sleep 2


echo -n "2 players playing txid "
curl --silent http://127.0.0.1:$player1_rpc_port/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"scinvoke","params":{"sc_dero_deposit":500000,"scid":"'"$scid"'","ringsize":2, "sc_rpc":[{"name":"entrypoint","datatype":"S","value":"Lottery"}] }}' -H 'Content-Type: application/json' | jq -r ".result.txid"
curl --silent http://127.0.0.1:$player2_rpc_port/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"scinvoke","params":{"sc_dero_deposit":400000,"scid":"'"$scid"'","ringsize":2, "sc_rpc":[{"name":"entrypoint","datatype":"S","value":"Lottery"}] }}' -H 'Content-Type: application/json' | jq -r ".result.txid"
mineblock
sleep 4

echo "SC DERO balance" $(scassetbalance $scid $baseasset )
echo "SC owner balance" $(balance $owner_rpc_port)
echo "SC player1 balance" $(balance $player1_rpc_port)
echo "SC player2 balance" $(balance $player2_rpc_port)

if [[ $(balance $player1_rpc_port) -lt 300000  &&  $(balance $player2_rpc_port)  -gt 790000  ]] ; then 
    exit 0 
else
    echo "test failed"
    exit 1
fi
