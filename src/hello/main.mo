import IC "./ic";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Deque "mo:base/Deque";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

shared(install) actor class dev() = this {
    private type canister_id = IC.canister_id;
    private let ic : IC.Self = actor "aaaaa-aa";
    private var canister_number : Nat = 0;
    private var canisters = TrieMap.TrieMap<Nat, canister_id>(Nat.equal, Hash.hash);
    private type Error = {
        #PermissionDenied;
    };

    public shared(caller) func create_canister() :  async Result.Result<canister_id, Error> {
        let settings = {
            freezing_threshold = null;
            controllers = ?[Principal.fromActor(this)];
            memory_allocation = null;
            compute_allocation = null;
        };
        let res = await ic.create_canister({ settings = ?settings;});
        canister_number += 1;
        canisters.put(canister_number, res.canister_id);
        #ok(res.canister_id)
    };

    public shared(caller) func install_code(wsm : [Nat8], canister_id : canister_id) : async Result.Result<Text, Error> {
        await ic.install_code({ 
            arg = [];
            wasm_module = wsm;
            mode = #install;
            canister_id = canister_id;
        });
        #ok("ok")
    };

    public shared(caller) func start_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
        await ic.start_canister({ canister_id = canister_id;});
        #ok("ok")
    };

    public shared(caller) func stop_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
        await ic.stop_canister({ canister_id = canister_id;});
        #ok("ok")
    };

    public shared(caller) func delete_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
        await ic.delete_canister({ canister_id = canister_id;});
        #ok("ok")
    };

};