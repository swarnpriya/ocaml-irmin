open Printf

(* Utility functions *)
(* U is a module with two functions *)
module U = struct
  let string_of_list f l = "[ " ^ List.fold_left (fun a b -> a ^ (f b) ^ "; ") "" l ^ "]"

  let print_header h = 
    begin 
      Printf.printf "%s\n" h;
      flush_all();
    end

  let (>>=) = Lwt.Infix.(>>=)

  let rec loop_until_y (msg:string) : unit Lwt.t = 
    Lwt_io.printf "%s" msg >>= fun _ ->
    Lwt_io.read_line Lwt_io.stdin >>= fun str ->
    if str="y" then Lwt.return ()
    else loop_until_y msg

  let fold f n b = 
    let rec fold_aux f i b = 
      if i >= n then b 
      else fold_aux f (i+1) @@ f i b in
    fold_aux f 0 b
end 

(* Canvas *)
let _ =
  U.print_header "Canvas"

module MkConfig (Vars: sig val root: string end) : Iheap_leftlist.Config = struct
  let root = Vars.root
  let shared = "/tmp/repos/shared.git"

  let init () =
    let _ = Sys.command (Printf.sprintf "rm -rf %s" root) in
    let _ = Sys.command (Printf.sprintf "mkdir -p %s" root) in
    ()
end

module Atom = struct
  type t = int32
  let t = Irmin.Type.int32
  let compare x y = Int32.to_int @@ Int32.sub x y
  let to_string = Int32.to_string
  let of_string = Int32.of_string
end

module CInit = MkConfig(struct let root = "/tmp/repos/canvas.git" end)
module MInit = Icanvas.MakeVersioned(CInit)(Atom)
module H = Heap_leftlist.Make(Atom)
module Vpst = MInit.Vpst

let bob_uri = "git+ssh://opam@172.18.0.3/tmp/repos/canvas.git#master"

let uris = [bob_uri]

let seed = 564294298

let canvas_size = 64

let (>>=) = Vpst.bind

let mk t = {M.max_x=canvas_size; M.max_y=canvas_size; M.t=t}

let loop_until_y msg = Vpst.liftLwt @@ U.loop_until_y msg

(* select a random number and insert it in the tree t *)
let do_an_insert t = 
  H.insert (Random.int32 900000l) t

(* it uses delete_min which removes the minimum element from t*)
let do_a_remove t = 
  if H.is_empty t then t
  else H.delete_min t

(* do_an_oper performs the operation either insert or remove
   : if input choosen is random number 0 or 1 then it performs insert else it performs remove *)
let do_an_oper t = 
  match Random.int 3 with
    | 0 | 1 -> do_an_insert t
    | _ -> do_a_remove t

let comp_time = ref 0.0

let sync_time = ref 0.0

let loop_iter i (pre: H.t Vpst.t) : H.t Vpst.t = 
  pre >>= fun t ->
  let t1 = Sys.time() in
  let c' =  U.fold (fun _ c -> do_an_oper c) 10 (mk t) in
  let t2 = Sys.time () in
  Vpst.sync_next_version ~v:c'.M.t uris >>= fun v ->
  let t3 = Sys.time () in
  begin 
    comp_time := !comp_time +. (t2 -. t1);
    sync_time := !sync_time +. (t3 -. t2);
    Vpst.return v
  end


let main_loop : H.t Vpst.t = 
  U.fold loop_iter 10 (Vpst.get_latest_version ())

let alice_f : unit Vpst.t = 
  loop_until_y "Ready?" >>= fun () ->
  main_loop >>= fun v ->
  let _ = printf "Done\n" in 
  let _ = printf "Computational time: %fs\n" !comp_time in
  let _ = printf "Merge time: %fs\n" !MInit.merge_time in
  let _ = printf "Sync time: %fs\n" !sync_time in
  Vpst.return ()

let main () =
  let _ = CInit.init () in
  let (f: M.t -> unit Vpst.t -> unit) = Vpst.with_init_version_do in
  Logs.set_reporter @@ Logs.format_reporter ();
  Logs.set_level @@ Some Logs.Error;
   (*
    * Alice starts with a blank canvas.
    *)
  f H.empty alice_f;;

main ();;
