import IC "./ic";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Deque "mo:base/Deque";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import TrieMap "mo:base/TrieMap";
import TrieSet "mo:base/TrieSet";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

shared(install) actor class icjj2(m : Nat, member : [Principal]) = this {
    private type canister_id = IC.canister_id;
    private let ic : IC.Self = actor "aaaaa-aa";

    private stable var canister_number : Nat = 0;
    private stable var canister_entries : [var (Nat, canister_id)]     = [var];
    private var canisters = TrieMap.fromEntries<Nat, canister_id>(canister_entries.vals(), Nat.equal, Hash.hash);
    private stable var members : [Principal] = [];
    private var member_set = TrieSet.fromArray<Principal>(member, Principal.hash, Principal.equal);
    private stable var N = member.size();
    private stable var M = do { 
        if (m >= members.size()) {
            members.size()
        } 
        else { 
            m
        };
    };
    private type Proposal = {
        content : [Nat8];
        done : Bool;
        var agreed : TrieSet.Set<Principal>;
    };
    private stable var pId : Nat = 1;
    private stable var proposal_entries : [var (Nat,Proposal)]     = [var];
    private var proposals = TrieMap.fromEntries<Nat, Proposal>(proposal_entries.vals(), Nat.equal, Hash.hash);

    private type Error = {
        #PermissionDenied;
        #ProposalNotFound;
        #MemberOnly;
    };

    public shared({caller}) func issuedProposal(cont : [Nat8]) : async Result.Result<() , Error> {
        if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        proposals.put(pId,{
            content=cont; 
            done=false; 
            var agreed=TrieSet.empty<Principal>();
            });
        return #ok();
    };
    public shared({caller}) func voteProposal(proposalId:Nat,vote : Bool) : async Result.Result<() , Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        switch(proposals.get(proposalId)){
            case null{
                return #err(#ProposalNotFound);
            };
            case (?v){
                if(vote){
                    let set =TrieSet.put<Principal>(v.agreed,caller,Principal.hash(caller),Principal.equal);
                    v.agreed := set;
                }
                else{
                    ignore TrieSet.delete<Principal>(v.agreed,caller,Principal.hash(caller),Principal.equal);
                };
                return #ok();
            };
        };
    };
    public shared({caller}) func executeProposal(proposalId:Nat) : async Result.Result<() , Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        switch(proposals.get(proposalId)){
            case null{
                return #err(#ProposalNotFound);
            };
            case (?v){
                if(TrieSet.size<Principal>(v.agreed)>=M){ //投票人数足够
                    //do someting for executing the proposal
                };
                return #ok();
            };
        };
        return #ok();
    };
    public shared({caller}) func create_canister() :  async Result.Result<canister_id, Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
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

    public shared({caller}) func install_code(wsm : [Nat8], canister_id : canister_id) : async Result.Result<Text, Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        await ic.install_code({ 
            arg = [];
            wasm_module = wsm;
            mode = #install;
            canister_id = canister_id;
        });
        #ok("ok")
    };

    public shared({caller}) func start_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        await ic.start_canister({ canister_id = canister_id;});
        #ok("ok")
    };

    public shared({caller}) func stop_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        await ic.stop_canister({ canister_id = canister_id;});
        #ok("ok")
    };

    public shared({caller}) func delete_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
         if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        await ic.delete_canister({ canister_id = canister_id;});
        #ok("ok")
    };

};
