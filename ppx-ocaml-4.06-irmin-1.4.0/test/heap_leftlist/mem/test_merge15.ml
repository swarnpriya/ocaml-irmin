(* original = | |
   q1 = |5|
   q2 = |5||6| *)
module U = struct
  let string_of_list f l = "[ " ^ List.fold_left (fun a b -> a ^ (f b) ^ "; ") "" l ^ "]"
  let print_header h = Printf.printf "%s" ("\n" ^ h ^ "\n")
end



(* Queue *)
let _ =
  U.print_header "Heap15";
  let module Atom = struct
  type t = int32
  let t = Irmin.Type.int32
  let compare x y = Int32.to_int @@ Int32.sub x y
  let to_string = Int32.to_string
  let of_string = Int32.of_string
end  in 

  let module H = Heap_leftlist.Make(Atom) in

  let original = H.empty |> H.insert (Int32.of_int 2) |> H.insert (Int32.of_int 3) |> H.insert (Int32.of_int 4)  in 
  let q1 =  original |> H.insert (Int32.of_int 5) |> H.delete_min |> H.insert (Int32.of_int 2)    in 
  let q2 = original |> H.delete_min |> H.delete_min in 
  (* Edit seq generation demonstration *)
  let edit_seq_printer = U.string_of_list (H.edit_to_string Atom.to_string) in 
  (* edit seq generation with diff *)
  let p = H.op_diff original q1 in
  let q = H.op_diff original q2 in
  let _ = Printf.printf "p = diff original v1: %s\n" (edit_seq_printer p);
    Printf.printf "q = diff original v2: %s\n" (edit_seq_printer q) in
  let p', q' = H.op_transform p q in
  let _ = 
    Printf.printf "p' = transformed p: %s\n" (edit_seq_printer p');
    Printf.printf "q' = transformed q: %s\n" (edit_seq_printer q')
  in 
  let m = H.merge3 original q1 q2 in 
  H.print_heap H.print_int32 m;
  
  print_newline();
  print_float !H.merge_time
