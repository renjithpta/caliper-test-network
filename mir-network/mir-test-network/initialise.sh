#!/bin/bash

#A script that executes the commands to initialise the test network (https://hyperledger-fabric.readthedocs.io/en/latest/create_channel/create_channel_test_net.html)
./network.sh $1
if [ "$1" == "down" ]; then
    exit 0
elif [ "$1" == "up" ]; then
    export PATH=${PWD}/../bin:$PATH
    export FABRIC_CFG_PATH=${PWD}/configtx
    configtxgen -profile TwoOrgsApplicationGenesis -outputBlock ./channel-artifacts/mychannel.block -channelID mychannel
    #Adding orderers to channel
    for i in {1..4}; do
        if [ "$i" == "1" ]; then
            echo -n "${i}st"
            i=""
        elif [ "$i" == "2" ]; then
            echo -n "${i}nd"
        elif [ "$i" == "3" ]; then
            echo -n "${i}rd"
        elif [ "$i" == "4" ]; then
            echo -n "${i}th"
        fi
        echo " Orderer"
        export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer${i}.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
        export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer${i}.example.com/tls/server.crt
        export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer${i}.example.com/tls/server.key
        if [ "$i" == "" ]; then
            i=1
        fi
        osnadmin channel join --channelID mychannel --config-block ./channel-artifacts/mychannel.block -o localhost:70$((i + 4))3 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
    done
    offset=0
    #Adding peers to channel
    for i in {1..2}; do
        echo -n "Org"
        if [ "$i" == "2" ]; then
            offset=1
        fi
        echo "${i} Peer"
        export CORE_PEER_TLS_ENABLED=true
        export CORE_PEER_LOCALMSPID="Org${i}MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${i}.example.com/peers/peer0.org${i}.example.com/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${i}.example.com/users/Admin@org${i}.example.com/msp
        export CORE_PEER_ADDRESS=localhost:$((i + 6 + offset))051
        export FABRIC_CFG_PATH=$PWD/../config/
        peer channel join -b ./channel-artifacts/mychannel.block
    done
    # Anchor peers cannot be set yet
    #Setting the 1st anchor peer
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    sleep 10
    peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile "$ORDERER_CA"
    cd channel-artifacts
    configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
    jq '.data.data[0].payload.data.config' config_block.json > config.json
    cp config.json config_copy.json
    jq '.channel_group.groups.Application.groups.Org1MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.org1.example.com","port": 7051}]},"version": "0"}}' config_copy.json > modified_config.json
    configtxlator proto_encode --input config.json --type common.Config --output config.pb
    configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
    configtxlator compute_update --channel_id mychannel --original config.pb --updated modified_config.pb --output config_update.pb
    configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
    echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
    configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb
    cd ..
    peer channel update -f channel-artifacts/config_update_in_envelope.pb -c mychannel -o localhost:7050  --ordererTLSHostnameOverride orderer.example.com --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
    #Setting the 2nd anchor peer
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
    cd channel-artifacts
    configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
    jq '.data.data[0].payload.data.config' config_block.json > config.json
    cp config.json config_copy.json
    jq '.channel_group.groups.Application.groups.Org2MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.org2.example.com","port": 9051}]},"version": "0"}}' config_copy.json > modified_config.json
    configtxlator proto_encode --input config.json --type common.Config --output config.pb
    configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
    configtxlator compute_update --channel_id mychannel --original config.pb --updated modified_config.pb --output config_update.pb
    configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
    echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
    configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb
    cd ..
    peer channel update -f channel-artifacts/config_update_in_envelope.pb -c mychannel -o localhost:7050  --ordererTLSHostnameOverride orderer.example.com --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
    #Confirm that the channel has been updated (block height should now be 3)
    peer channel getinfo -c mychannel
    #Connecting to 1st orderer as Org1 peer so change environment variables
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
    #Retrieve latest config block (genesis block)
    peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile "$ORDERER_CA"
    echo "Deploying chaincode"
    ./network.sh deployCC -ccn basic -ccp ../chaincode/asset-transfer-basic/chaincode-javascript/ -ccl javascript -cccg ./collections-config.json -ccep "OR('Org1MSP.peer','Org2MSP.peer')"  -c mychannel
    echo "Invoking chaincode"
    peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" -C mychannel -n basic --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" -c '{"function":"InitLedger","Args":[]}'
    echo "Confirm the assets were added to the ledger"
    peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'
fi
