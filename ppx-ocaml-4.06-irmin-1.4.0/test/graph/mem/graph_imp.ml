open Printf

module type ATOM = sig
  type t
  val t: t Irmin.Type.t
  val compare: t -> t -> int
end

module Edge_type = 
   struct 
   type t = (string * int64)
   let t = let open Irmin.Type in pair string int64 
   let compare = Pervasives.compare
   end 

module Make =
  struct
   (* labels for nodes **)
  
   module OS = Set_imp.Make(Edge_type)

   open OS
   type nlabel = string
   
   (* labels for edges *)
   type elabel = string

   (* node *)
   type node = int64

   (* labelled node *) 
   type lnode = (node * nlabel)

   (* edge containing pairs of node *)
   type edge = (node * node)

   (* labelled edge *)
   type ledge = (edge * elabel)

   (* labelled link from a node *)
   (* here label represents the edge label *)
   type in_edge = OS.t

   (* labelled link to a node *)
   (* here label represents he edge label *)
   type out_edge = OS.t

   (* pair of link to the node, node, label, link from the node 
      node represented by node type, label represented by label type, 
      in_edge reprsents the edges from its predecessors 
      to it and out_edge represents the edges to its successors. *)
   type context = (in_edge * node * nlabel * out_edge)
    

   (* A graph is either an empty graph or a graph extended by a new node v together with its 
      label and with edges to its succesors and predecessors that
      are already in the graph *)
   (* It is not similar to list because it cannot be freely generated by Empty and G *)
   type gnode = (context * t)
   and t = 
           | E_G 
           | G of gnode

    exception Empty

   let empty = E_G

   let is_empty g = function 
     | E_G -> true 
     | G a -> false 

   (* check whether node n belongs to a context c or not *)
   let belongs_node_c n = function 
     | (il, a, l, ol) -> if n = a then true else false 


   (* get the node referred in the context c *)
   let get_node c = match c with 
     | (il, n, l, rl) -> n
   
   (* get the edge directed towards the node n *)
   let get_in_edge = function 
      | (il, n, l, ol) -> il 
  
   (* get the edge directed from the node n *)
   let get_out_edge = function 
      | (il, n, l, ol) -> ol 

   let rec get_in_edge_g n g = match g with 
    | E_G -> OS.empty
    | G(x, xl) -> if (get_node x = n) then get_in_edge x else 
                   get_in_edge_g n xl

   let rec get_out_edge_g n g = match g with 
    | E_G -> OS.empty
    | G(x, xl) -> if (get_node x = n) then get_out_edge x else 
                   get_out_edge_g n xl

   (* get the label referred in the context c *)
   let get_label c = match c with 
     | (il, n, l, rl) -> l
    
   (* get the node with its label referred in the context c *)
   let get_node_with_label c = function 
     | (il, n , l , rl) -> (n, l)
    
   (* check whether a node is present in the graph or not *)
   let rec check_node n = function 
     | E_G -> false
     | G (x, xl) -> if (get_node x = n) then true else check_node n xl

   (* get the context for a node n in the graph *)
    let rec get_context n g = match g with 
     | G (x, xl) -> if (get_node x = n) then x else get_context n xl


    let rec snd_mem x c = match c with 
      | OS.Empty -> false
      | OS.Node {l; v; r;_} ->
          let c = Pervasives.compare x (snd v) in
          (c = 0) || (snd_mem x (if c < 0 then l else r))


    let rec check_a_node_all_labels n g = match g with 
      | E_G -> false 
      | G(x, xl) -> if (snd_mem n (get_in_edge x) || snd_mem n (get_out_edge x))
                      then true 
                      else check_a_node_all_labels n xl

    let rec filter_successor n lb (c : out_edge) = match c with 
     | Empty -> OS.Empty
     | Node { l = ll; v = lv; r = lr;_} -> 
       if (((snd lv) = n) && ((fst lv) = lb)) then 
       (OS.remove lv c) else 
       if n < snd lv then 
       begin
       let ll' = (filter_successor n lb ll) in 
       let hl = OS.height ll' in
       let hr = OS.height lr in 
       let h' = if hl > hr then Int64.of_int (Int64.to_int hl + 1) 
                          else Int64.of_int (Int64.to_int hr + 1) in  
       Node {l = ll'; v = lv; r = lr;h=h'}
     end 
      else 
       begin
       let lr' = (filter_successor n lb lr) in 
       let hr = OS.height lr' in
       let hl = OS.height ll in 
       let h' = if hl > hr then Int64.of_int (Int64.to_int hl + 1) 
                          else Int64.of_int (Int64.to_int hr + 1) in  
       Node {l = ll; v = lv; r = lr';h=h'}
     end 

    let rec filter_predecessor n lb (c : in_edge) = match c with 
     | Empty -> OS.Empty
     | Node { l = ll; v = lv; r = lr;_} -> 
       if (((snd lv) = n) && ((fst lv) = lb)) then 
       (OS.remove lv c) else 
       if n < snd lv then 
       begin
       let ll' = (filter_predecessor n lb ll) in 
       let hl = OS.height ll' in
       let hr = OS.height lr in 
       let h' = if hl > hr then Int64.of_int (Int64.to_int hl + 1) 
                          else Int64.of_int (Int64.to_int hr + 1) in  
       Node {l = ll'; v = lv; r = lr;h=h'}
     end 
      else 
       begin
       let lr' = (filter_predecessor n lb lr) in 
       let hr = OS.height lr' in
       let hl = OS.height ll in 
       let h' = if hl > hr then Int64.of_int (Int64.to_int hl + 1) 
                          else Int64.of_int (Int64.to_int hr + 1) in  
       Node {l = ll; v = lv; r = lr';h=h'}
     end

    let rec filter_p_s n c = match c with 
     | OS.Empty -> OS.Empty
     | OS.Node { l = ll; v = lv; r = lr;_} -> 
       if ((snd lv) = n) then 
       (OS.remove lv c) else 
       if n < snd lv then 
       begin
       let ll' = (filter_p_s n ll) in 
       let hl = OS.height ll' in
       let hr = OS.height lr in 
       let h' = if hl > hr then Int64.of_int (Int64.to_int hl + 1) 
                          else Int64.of_int (Int64.to_int hr + 1) in  
       Node {l = ll'; v = lv; r = lr;h=h'}
     end 
      else 
       begin
       let lr' = (filter_p_s n lr) in 
       let hr = OS.height lr' in
       let hl = OS.height ll in 
       let h' = if hl > hr then Int64.of_int (Int64.to_int hl + 1) 
                          else Int64.of_int (Int64.to_int hr + 1) in  
       Node {l = ll; v = lv; r = lr';h=h'}
     end 

   (* gives the degree of any node n *)
   let rec degree n = function 
    | E_G -> 0 
    | G (x, xl) -> if (get_node x = n) then (OS.cardinal (get_in_edge x)) + 
                                            (OS.cardinal (get_out_edge x)) 
                                       else (degree n xl)

   (* gives list of all the nodes present in the graph g *)
   let rec get_nodes g = match g with 
    | E_G -> []
    | G (x, xl) -> get_node x :: (get_nodes xl)

    (* gives list of all the nodes present in the graph g *)
   let rec get_labels g = match g with 
    | E_G -> []
    | G (x, xl) -> get_label x :: (get_labels xl)
   
   (* gives all the nodes along with its label present in the graph g *)
   let rec get_nodes_with_label g = match g with 
    | E_G -> []
    | G (x, xl) -> get_node_with_label x :: (get_nodes_with_label xl)


   let rec add_context c g = match g with 
    | E_G -> G(c, E_G)
    | G (x, xl) -> let x' = add_context c xl in 
                   G (x, x')
 

   (* gives the number of nodes present in the graph *)
   let number_of_nodes g = List.length (get_nodes g)

   let rec update_context n c' = function
    | E_G -> E_G 
    | G(x, xl) -> if (get_node x) = n 
                  then G(c', xl) else G(x, (update_context n c' xl))

   let rec update_all_context_p_s n = function
    | E_G -> E_G 
    | G(x, xl) -> G(((filter_p_s n (get_in_edge x)),
                   (get_node x),
                   (get_label x),
                   (filter_p_s n (get_out_edge x))), update_all_context_p_s n xl)

   (* insert node n *)
   let rec insert_node n l = function
    | E_G -> G ((OS.empty, n, l, OS.empty), E_G)
    | G (x, xl) -> (add_context (OS.empty,n,l,OS.empty) (G(x,xl)))


   (* insert the edge from v to w with label l *)
   let rec insert_edge v w l = function 
    | E_G -> E_G
    | G (x, xl) -> if (get_node x = v) then G((get_in_edge x,
                                             get_node x,
                                             get_label x,
                                               OS.add (l,w) (get_out_edge x)),
                                               xl) 
                                       else G(x, insert_edge v w l xl)



     (* delete node n *)
   let rec delete_node n = function 
    | E_G -> E_G 
    | G (x, xl) -> if (get_node x = n) then (update_all_context_p_s n xl)
                                       else G(x, delete_node n xl)

   let rec delete_nodes nl g = match nl with 
    | [] -> g 
    | x :: xl -> begin
                 let g' = delete_node x g in 
                 delete_nodes xl g'
                 end 

   (* delete edge from v to w *)
   let rec delete_edge v w l = function 
    | E_G -> E_G
    | G (x, xl) -> if (get_node x = v) 
                   then if (OS.mem (l,w) (get_out_edge x)) 
                        then G (((get_in_edge x), 
                                 (get_node x), 
                                 (get_label x), 
                                 (filter_successor w l (get_out_edge x))), xl)
                        else  let c' = get_context w (G(x, xl)) in 
                              let c = ((filter_predecessor w l (get_in_edge x)),
                                     (get_node c'),
                                     (get_label c'),
                                     (get_out_edge c')) in 
                             (update_context w c (G(x,xl)))
                  else G (x, (delete_edge v w l xl))
  

   (* check the membership of a context in g *)
   let rec is_mem_G c g = match g with 
    | E_G -> false
    | G(x, xl) -> if x = c then true else is_mem_G c xl

   (* get all the edges in the context c*)
   let get_edges_in_context c = function 
     | (p, n, l, s) -> 
       let rec get_in_edge el = 
       match p with
       | []-> []
       | (x :: xl) -> (snd x, n) :: get_in_edge xl in 
       let rec get_out_edge el = 
       match s with 
       | [] -> []
       | (y :: yl) -> (n, snd y) :: get_out_edge yl in 
      List.append (get_in_edge p) (get_out_edge s) 

    (* get all edges in graph g *)
    let rec get_edges g = match g with 
      | E_G -> []
      | G (x, y) -> get_edges_in_context x :: get_edges y 

    (*let rec graph_to_set g1 = match g1 with 
      | E_G -> OS.Empty 
      | G(x, E_G) -> OS.singleton x 
      | G(x, xl) -> let sxl = graph_to_set xl in 
                    (OS'.union (OS'.singleton x) sxl)*)

    let rec get_common_nodes g1 g2 = match (g1,g2) with 
      | E_G, E_G -> []
      | G(x, xl), E_G -> []
      | E_G, G(x, xl) -> []
      | G(x, xl), G(y,yl) -> if List.mem (get_node x) (get_nodes g2) &&
                                List.mem (get_label x) (get_labels g2) 
                             then (get_node x) :: get_common_nodes xl yl 
                             else get_common_nodes xl g2

    let rec get_diff_nodes g1 g2 = match (g1,g2) with 
      | E_G, E_G -> []
      | G(x, xl), E_G -> get_nodes g1 
      | E_G, G(x, xl) -> []
      | G(x, xl), G(y,yl) -> if List.mem (get_node x) (get_nodes g2) &&
                                List.mem (get_label x) (get_labels g2) 
                             then get_diff_nodes xl yl 
                             else get_node x :: get_diff_nodes xl g2
    
    let rec get_all_contexts g1 = match g1 with 
      | E_G -> []
      | G(x, xl) -> x :: get_all_contexts xl 

    let rec get_diff_context g1 g2 = match (g1, g2) with 
      | E_G, E_G -> []
      | G(x, xl), E_G -> get_all_contexts g1
      | E_G, G(x, xl) -> []
      | G(x, xl), G(y,yl) -> if List.mem (get_node x) (get_nodes g2) &&
                                List.mem (get_label x) (get_labels g2) then get_diff_context xl g2 
                             else x :: get_diff_context xl g2

    let rec get_common_context g1 g2 = match (g1, g2) with 
      | E_G, E_G -> []
      | G(x, xl), E_G -> []
      | E_G, G(x, xl) -> []
      | G(x, xl), G(y,yl) -> if List.mem x (get_all_contexts g2) then get_diff_context xl g2 
                             else x :: get_diff_context xl g2

    let rec update_common_nodes cl g1 g2 = match cl with 
      | [] -> g2 
      | x :: xl -> let cg1 = get_context x g1 in 
                   let cg2 = get_context x g2 in 
                   let uc = ((OS.merge3 OS.Empty (get_in_edge cg1) (get_in_edge cg2)),
                              x, 
                              get_label cg1,
                             (OS.merge3 OS.Empty (get_out_edge cg1) (get_out_edge cg2))) in 
                   let g2' = update_context x uc g2 in 
                   update_common_nodes xl g1 g2'

      let rec add_context c g1 = match g1 with 
      | E_G -> G(c, E_G)
      | G(x, xl) -> G(x, add_context c xl)

    let rec add_contexts cl g1 = match cl with 
      | [] -> g1
      | x :: xl -> begin
                   let g1' = add_context x g1 in 
                   add_contexts xl g1' 
                   end

    let rec remove_context x g1 = match g1 with 
     | E_G -> E_G 
     | G(y, yl) -> if x = y then yl else G(y, (remove_context x yl))

    let rec update_common_nodes_with_ancestor cl o g1 g2 = match cl with 
      | [] ->  
        let dcg1g2 = get_diff_context g1 g2 in
        let cng1g2 = get_common_nodes g1 g2 in 
        let g2' = update_common_nodes cng1g2 g1 g2 in
        add_contexts dcg1g2 g2'
      | x :: xl -> let cg1 = get_context x g1 in 
                   let cg2 = get_context x g2 in 
                   let co = get_context x o in 
                   let uc = ((OS.merge3 (get_in_edge co) (get_in_edge cg1) (get_in_edge cg2)),
                              x, 
                              get_label cg1,
                             (OS.merge3 (get_out_edge co) (get_out_edge cg1) (get_out_edge cg2))) in 
                   let g2' = update_context x uc g2 in 
                   update_common_nodes_with_ancestor xl (remove_context (get_context x o) o) 
                                                        (remove_context (get_context x g1) g1) g2'


    let rec get_intercept_l l1 l2 = match (l1,l2) with 
     | [], [] -> []
     | l1, [] -> []
     | [], l2 -> []
     | x::xl, y::yl -> if List.mem x l2 then x :: get_intercept_l xl l2 
                       else get_intercept_l xl l2

   let merge_time = ref 0.0

    let merge3 o g1 g2 = match (o, g1, g2) with 
      | E_G, E_G, E_G -> E_G 
      | E_G, E_G, g2 -> g2 
      | E_G, g1, E_G -> g1 
      | o, E_G, E_G -> E_G
      | o, g1, E_G -> 
        begin
        let cng1oc = get_common_nodes g1 o in 
        delete_nodes cng1oc g1 
        end 
      | o, E_G, g2 -> 
        begin
        let cng1oc = get_common_nodes g2 o in 
        delete_nodes cng1oc g2 
        end 
      | E_G, g1, g2 -> 
        let dcg1g2 = get_diff_context g1 g2 in
        let cng1g2 = get_common_nodes g1 g2 in 
        let g2' = update_common_nodes cng1g2 g1 g2 in
        add_contexts dcg1g2 g2' 
     | G(x,xl), G(y,yl), G(z,zl) ->
       let cng1g2 = get_common_nodes g1 g2 in
       let cnog1 = get_common_nodes g1 o in 
       let cnog2 = get_common_nodes g2 o in 
       let il = get_intercept_l cng1g2 (get_intercept_l cnog1 cnog2) in  
       let dng1o = get_diff_nodes o g1 in
       let dng2o = get_diff_nodes o g2 in
       let mg1 = update_common_nodes_with_ancestor il o g1 g2 in 
       let mg2 = delete_nodes dng1o mg1 in 
      delete_nodes dng2o mg2

    let merge3 o v1 v2 = 
    let t1 = Sys.time () in
    let res = merge3 o v1 v2 in
    let t2 = Sys.time () in
    begin
      merge_time := !merge_time +. (t2-.t1);
      res;
    end 


   let print_int64 i = output_string stdout (string_of_int (Int64.to_int i))


    let print_pair f f' p = 
     let rec print_elements = function 
     | (x,y) -> (f x, f' y) in 
     print_string "(";
     print_elements p;
     print_string ")"

   let print_list f l = 
    let rec print_elements = function 
    | [] -> ()
    | x :: xl -> f x ; print_elements xl in 
      print_string "[";
      print_elements l;
      print_string "]"


   let print_c f f' f'' c = 
     let rec print_elements = function
      | (p, n, l, s) ->
         f' p ;
         f n ;
         f'' l; 
         f' s in 
        print_string "{";
        print_elements c;
        print_string "}" 

   let rec print_graph g = match g with 
       | E_G -> print_string "E_G"
       | G (a, x) -> (OS.print_set (print_pair (print_string) (print_int64)) (get_in_edge a)) ;
                      print_int64 (get_node a);
                      print_string (get_label a);
                      (OS.print_set (print_pair (print_string) (print_int64)) (get_out_edge a));
                      print_string "&"; 
                      print_graph x





 end