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
//如果一个canister被限制了则升级代码和关闭必须通过提案
//提案通过后需要member去执行executeProposal函数
shared(install) actor class icjj2(m : Nat, member : [Principal]) = this {
    private type canister_id = IC.canister_id;
    private type Oprate = {
        #InstallCode;
        #StopCanister;
    };
    private type InstallCodeArgs = {
        wsm : [Nat8];
        canister_id : canister_id;
    };
    private type StopCanisterArgs = {
        canister_id : canister_id;
    };
    private type ProposalAgrs = {
        oprate : Oprate;
        memo : Text;
        install_code_args : ?InstallCodeArgs;
        stop_canister_args : ?StopCanisterArgs;
    };
    private type Proposal = {
        args : ProposalAgrs;
        done : Bool;
        var agreed : TrieSet.Set<Principal>;
    };
    private type Error = {
        #PermissionDenied;
        #ProposalNotFound;
        #MemberOnly;
        #ArgsError;
        #RestrictedCanister;
    };
    
    private let ic : IC.Self = actor "aaaaa-aa";
    private stable var canisters_entires : [Principal] = [];
    private var canisters = TrieSet.fromArray<Principal>(canisters_entires, Principal.hash, Principal.equal);
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
    private stable var pId : Nat = 1;
    private stable var proposal_entries : [var (Nat,Proposal)]     = [var];
    private var proposals = TrieMap.fromEntries<Nat, Proposal>(proposal_entries.vals(), Nat.equal, Hash.hash);
    private stable var restricted_canister_entries : [Principal] = [];
    private var restricted_canisters = TrieSet.fromArray<Principal>(member, Principal.hash, Principal.equal);
    //后续可以改成通过提案执行
    public shared({caller}) func setRestrictedCanister(arg : Bool,id : Principal) : async Result.Result<() , Error> {
        if(caller != Principal.fromActor(this)){
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
        };
        if(arg){
            ignore TrieSet.put<Principal>(restricted_canisters,id,Principal.hash(id),Principal.equal);
        }else{
            ignore TrieSet.delete<Principal>(restricted_canisters,id,Principal.hash(id),Principal.equal);
        };
        return #ok();
    };
    
    public shared({caller}) func issuedProposal(args : ProposalAgrs) : async Result.Result<() , Error> {
        if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
            return #err(#MemberOnly);
        };
        proposals.put(pId,{
            args=args; 
            done=false; 
            var agreed=TrieSet.empty<Principal>();
        });
        pId+=1;
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
                    proposals.put(proposalId,v);
                }
                else{
                    let set =TrieSet.delete<Principal>(v.agreed,caller,Principal.hash(caller),Principal.equal);
                    v.agreed := set;
                    proposals.put(proposalId,v);
                };
                return #ok();
            };
        };
    };
    
 
    public shared({caller}) func executeProposal(proposalId:Nat) : async Result.Result<() , Error> {
        if(caller != Principal.fromActor(this)){
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
        };
        switch(proposals.get(proposalId)){
            case null{
                return #err(#ProposalNotFound);
            };
            case (?v){
                if(TrieSet.size<Principal>(v.agreed)>=M){ //投票人数足够
                    //do someting for executing the proposal
                    switch(v.args.oprate){
                        case(#InstallCode){
                            switch(v.args.install_code_args){
                                case null{
                                    return #err(#ArgsError);
                                };
                                case (?install_args){
                                   ignore await install_code(install_args.wsm,install_args.canister_id);
                                };
                            };
                        };
                        case(#StopCanister){
                            switch(v.args.stop_canister_args){
                                case null{
                                    return #err(#ArgsError);
                                };
                                case (?stop_canister_args){
                                   ignore await stop_canister(stop_canister_args.canister_id);
                                };
                            };
                        };
                    };
                };
                return #ok();
            };
        };
        return #ok();
    };
    public shared({caller}) func create_canister(is_restirct : Bool) :  async Result.Result<canister_id, Error> {
        if(caller != Principal.fromActor(this)){
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
        };
        let settings = {
            freezing_threshold = null;
            controllers = ?[Principal.fromActor(this)];
            memory_allocation = null;
            compute_allocation = null;
        };
        let res = await ic.create_canister({ settings = ?settings;});
        ignore TrieSet.put<Principal>(canisters,res.canister_id,Principal.hash(res.canister_id),Principal.equal);
        if(is_restirct){
            ignore TrieSet.put<Principal>(restricted_canisters,res.canister_id,Principal.hash(res.canister_id),Principal.equal);
        };
        #ok(res.canister_id)
    };

    public shared({caller}) func install_code(wsm : [Nat8], canister_id : canister_id) : async Result.Result<Text, Error> {
        if(caller != Principal.fromActor(this)){
            if(TrieSet.mem(restricted_canisters,canister_id,Principal.hash(caller),Principal.equal) ){
                return #err(#RestrictedCanister);
            }else
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
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
        if(caller != Principal.fromActor(this)){
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
        };
        await ic.start_canister({ canister_id = canister_id;});
        #ok("ok")
    };

    public shared({caller}) func stop_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
        if(caller != Principal.fromActor(this)){
            if(TrieSet.mem(restricted_canisters,canister_id,Principal.hash(caller),Principal.equal)){
                return #err(#RestrictedCanister);
            };
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
        };
        await ic.stop_canister({ canister_id = canister_id;});
        #ok("ok")
    };

    public shared({caller}) func delete_canister(canister_id : canister_id) : async Result.Result<Text, Error> {
        if(caller != Principal.fromActor(this)){
            if(not TrieSet.mem(member_set,caller,Principal.hash(caller),Principal.equal)){
                return #err(#MemberOnly);
            };
        };
        await ic.delete_canister({ canister_id = canister_id;});
        #ok("ok")
    };

}; 
