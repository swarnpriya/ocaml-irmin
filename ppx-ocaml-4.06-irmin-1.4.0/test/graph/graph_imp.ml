open Printf
exception Empty
module type ATOM = sig
  type t
  val t: t Irmin.Type.t
  val to_string : t -> string   
  val of_string: string -> t
  val compare: t -> t -> int
  (*include Msigs.RESOLVEABLE with type t := t*)
end

module Make =
  struct
   (* labels for nodes **)
   type nlabel = char 
   
   (* labels for edges *)
   type elabel = char 

   (* node *)
   type node = int64

   (* labelled node *) 
   type lnode = (node * nlabel)

   (* edge containing pairs of node *)
   type edge = (node * node)

   (* labelled edge *)
   type ledge = (edge * elabel)

   (* path is the list of node *)
   type path = node list

   (* labelled path is the list of labelled node *)
   type lpath = lnode list

   (* labelled link from a node *)
   (* here label represents the edge label *)
   type in_edge = (elabel * node) list

   (* labelled link to a node *)
   (* here label represents he edge label *)
   type out_edge = (elabel * node) list

   (* pair of link to the node, node, label, link from the node 
      node represented by node type, label represented by label type, 
      in_edge reprsents the edges from its predecessors 
      to it and out_edge represents the edges to its successors. *)
   type context = (in_edge * node * nlabel * out_edge)
    

   (* A graph is either an empty graph or a graph extended by a new node v together with its 
      label and with edges to its succesors and predecessors that
      are already in the graph *)
   (* It is not similar to list because it cannot be freely generated by Empty and G *)
   type t = 
           | E_G 
           | G of (context * t)

   let empty = E_G

   let is_empty g = function 
     | E_G -> true 
     | G a -> false 

   (* check whethen node n belongs to a context c or not *)
   let belongs_node_c n = function 
     | (il, a, l, ol) -> if n = a then true else false 
   
   (* get the edge directed towards the node n *)
   let get_in_edge = function 
      | (il, n, l, ol) -> il 
  
   (* get the edge directed from the node n *)
   let get_out_edge = function 
      | (il, n, l, ol) -> ol 

   (* get the node referred in the context c *)
   let get_node c = match c with 
     | (il, n, l, rl) -> n

   (* get the label referred in the context c *)
   let get_label c = match c with 
     | (il, n, l, rl) -> l
    
   (* get the node with its label referred in the context c *)
   let get_node_with_label c = function 
     | (il, n , l , rl) -> (n, l)
    
   (* check whether a node is present in the graph or not *)
   let rec check_node n = function 
     | E_G -> raise Empty 
     | G (x, xl) -> if (get_node x = n) then true else check_node n xl

   (* get the context for a node n in the graph *)
    let rec get_context n = function
     | E_G -> raise Empty 
     | G (x, xl) -> if (get_node x = n) then x else get_context n xl

    let rec filter_successor n (c:out_edge) = match c with 
     | [] -> []
     | x :: xl -> if ((snd x) = n) then xl else x :: filter_successor n xl

   (* gives the degree of any node n *)
   let rec degree n = function 
    | E_G -> 0 
    | G (x, xl) -> if (get_node x = n) then (List.length (get_in_edge x)) + 
                                            (List.length (get_out_edge x)) 
                                       else (degree n xl)

   (* gives list of all the nodes present in the graph g *)
   let rec get_nodes g = match g with 
    | E_G -> []
    | G (x, xl) -> get_node x :: (get_nodes xl)
   
   (* gives all the nodes along with its label present in the graph g *)
   let rec get_nodes_with_label g = match g with 
    | E_G -> []
    | G (x, xl) -> get_node_with_label x :: (get_nodes_with_label xl)
 

   (* gives the number of nodes present in the graph *)
   let number_of_nodes g = List.length (get_nodes g)

   (* gives the list of successors nodes for a node n *)
   let rec succ n = function
    | E_G -> []
    | G (x, xl) -> if (get_node x = n) then List.map (snd) (get_out_edge x) 
                                       else succ n xl

   (* gives the list of predecessor nodes for a node n *)
   let rec pred n = function
    | E_G -> []
    | G (x, xl) -> if (get_node x = n) then List.map (snd) (get_in_edge x) 
                                       else pred n xl

   (* insert the edge from v to w with label l *)
   let rec insert_edge v w l = function 
    | E_G -> raise Empty 
    | G (x, xl) -> if (get_node x = v) then List.append [(l,w)] (get_out_edge x) 
                                       else insert_edge v w l xl
   (* delete edge from v to w *)
   let rec delete_edge v w = function 
    | E_G -> raise Empty 
    | G (x, xl) -> if (get_node x = v) 
                   then G (((get_in_edge x), 
                   	        (get_node x), 
                   	        (get_label x), 
                   	        (filter_successor w (get_out_edge x))), xl)
                   else G (x, (delete_edge v w xl))
    
   (* delete node n *)
   let rec delete_node n = function 
    | E_G -> raise Empty 
    | G (x, xl) -> if (get_node x = n) then xl 
                                       else delete_node n xl

   (* insert node n *)
   let rec insert_node n l p s = function
    | E_G -> G (([], n, l, []), E_G)
    | G (x, xl) -> G ((p, n, l, s), G(x, xl))

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

    (* gives the list of new nodes present in g2 whicg are not
       present in g1 *)
    let rec compare_nodes g1 g2 = match (g1, g2) with 
      | [], [] -> []
      | G(x, xl), G(y,yl) ->if x = y then compare_nodes xl yl 
                                     else y :: compare_nodes xl yl 

   (* Merging *)
   type edit = 
    | Delete_node of node 
    | Delete_edge of node * node * elabel 
    | Insert_node of node * nlabel * in_edge * out_edge 
    | Insert_edge of node * node * elabel

   let rec edit_distance g1 g2 = match (g1, g2) with 
    | E_G, E_G -> []
    | E_G, G(x, xl) -> Insert_node (get_node x, get_label x, get_in_edge x, get_out_edge x) :: edit_distance E_G xl 
    | G(x, xl), E_G -> Delete_node (get_node x) :: edit_distance xl E_G
    | G(x, xl), G(y, yl) -> 
      let n = get_nodes G(x, xl) in 
      let e = get_edges G(x, xl) in 
      let n' = get_nodes G(y, yl) in 
      let e' = get_edges G(y, yl) in 
      if n= n' && e = e' then [] 
                         else if n < n' then
                                 let cl = compare_nodes G(x, xl) G(y, yl) in 
                                 let rec insert_all el = match el in 
                                    | [] -> []
                                    | x :: xl -> Insert_node x :: insert_all xl








   (*let print_int64 i = output_string stdout (string_of_int (Int64.to_int i))

   let print_list f lst = 
    let rec print_elements = function
      | [] -> ()
      | x :: xl -> f x ; print_elements xl in 
    print_string "[";
    print_elements lst;
    print_string "]"

    let print_pair f f' p = 
     let print_elements = function
     | (x,y) -> (f x, f' y) in 
     print_string "(";
     print_elements;
     print_string ")"

   let print_adj_list l = print_list (print_pair (print_char) (print_int64)) l

   let print_c f f' c = 
     let rec print_elements = function
      | {a_t= at; n = n'; a_f = af} ->
         f' at ;
         f n' ;
         f' af in 
        print_string "}";
        print_elements;
        print_string "}" 

   let print_graph f g = 
     let rec print_elements = function 
       | E_G -> ()
       | G a -> f a in 
         print_string "Graph";
         print_elements*)




 end