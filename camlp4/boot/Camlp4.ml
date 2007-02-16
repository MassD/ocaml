module Debug :
  sig
    (****************************************************************************)
    (*                                                                          *)
    (*                              Objective Caml                              *)
    (*                                                                          *)
    (*                            INRIA Rocquencourt                            *)
    (*                                                                          *)
    (*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
    (*  en Automatique.  All rights reserved.  This file is distributed under   *)
    (*  the terms of the GNU Library General Public License, with the special   *)
    (*  exception on linking described in LICENSE at the top of the Objective   *)
    (*  Caml source tree.                                                       *)
    (*                                                                          *)
    (****************************************************************************)
    (* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)
    (* camlp4r *)
    type section = string
    val mode : section -> bool
    val printf : section -> ('a, Format.formatter, unit) format -> 'a
  end =
  struct
    (****************************************************************************)
    (*                                                                          *)
    (*                              Objective Caml                              *)
    (*                                                                          *)
    (*                            INRIA Rocquencourt                            *)
    (*                                                                          *)
    (*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
    (*  en Automatique.  All rights reserved.  This file is distributed under   *)
    (*  the terms of the GNU Library General Public License, with the special   *)
    (*  exception on linking described in LICENSE at the top of the Objective   *)
    (*  Caml source tree.                                                       *)
    (*                                                                          *)
    (****************************************************************************)
    (* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)
    (* camlp4r *)
    open Format
    module Debug = struct let mode _ = false end
    type section = string
    let out_channel =
      try
        let f = Sys.getenv "CAMLP4_DEBUG_FILE"
        in
          open_out_gen [ Open_wronly; Open_creat; Open_append; Open_text ]
            0o666 f
      with | Not_found -> stderr
    module StringSet = Set.Make(String)
    let mode =
      try
        let str = Sys.getenv "CAMLP4_DEBUG" in
        let rec loop acc i =
          try
            let pos = String.index_from str i ':'
            in
              loop (StringSet.add (String.sub str i (pos - i)) acc) (pos + 1)
          with
          | Not_found ->
              StringSet.add (String.sub str i ((String.length str) - i)) acc in
        let sections = loop StringSet.empty 0
        in
          if StringSet.mem "*" sections
          then (fun _ -> true)
          else (fun x -> StringSet.mem x sections)
      with | Not_found -> (fun _ -> false)
    let formatter =
      let header = "camlp4-debug: " in
      let normal s =
        let rec self from accu =
          try
            let i = String.index_from s from '\n'
            in self (i + 1) ((String.sub s from ((i - from) + 1)) :: accu)
          with
          | Not_found ->
              (String.sub s from ((String.length s) - from)) :: accu
        in String.concat header (List.rev (self 0 [])) in
      let after_new_line str = header ^ (normal str) in
      let f = ref after_new_line in
      let output str chr =
        (output_string out_channel (!f str);
         output_char out_channel chr;
         f := if chr = '\n' then after_new_line else normal)
      in
        make_formatter
          (fun buf pos len ->
             let p = pred len in output (String.sub buf pos p) buf.[pos + p])
          (fun () -> flush out_channel)
    let printf section fmt = fprintf formatter ("%s: " ^^ fmt) section
  end
module Options :
  sig
    (****************************************************************************)
    (*                                                                          *)
    (*                              Objective Caml                              *)
    (*                                                                          *)
    (*                            INRIA Rocquencourt                            *)
    (*                                                                          *)
    (*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
    (*  en Automatique.  All rights reserved.  This file is distributed under   *)
    (*  the terms of the GNU Library General Public License, with the special   *)
    (*  exception on linking described in LICENSE at the top of the Objective   *)
    (*  Caml source tree.                                                       *)
    (*                                                                          *)
    (****************************************************************************)
    (* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)
    type spec_list = (string * Arg.spec * string) list
    val init : spec_list -> unit
    val add : string -> Arg.spec -> string -> unit
    (** Add an option to the command line options. *)
    val print_usage_list : spec_list -> unit
    val ext_spec_list : unit -> spec_list
    val parse : (string -> unit) -> string array -> string list
  end =
  struct
    (****************************************************************************)
    (*                                                                          *)
    (*                              Objective Caml                              *)
    (*                                                                          *)
    (*                            INRIA Rocquencourt                            *)
    (*                                                                          *)
    (*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
    (*  en Automatique.  All rights reserved.  This file is distributed under   *)
    (*  the terms of the GNU Library General Public License, with the special   *)
    (*  exception on linking described in LICENSE at the top of the Objective   *)
    (*  Caml source tree.                                                       *)
    (*                                                                          *)
    (****************************************************************************)
    (* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)
    type spec_list = (string * Arg.spec * string) list
    open Format
    let rec action_arg s sl =
      function
      | Arg.Unit f -> if s = "" then (f (); Some sl) else None
      | Arg.Bool f ->
          if s = ""
          then
            (match sl with
             | s :: sl ->
                 (try (f (bool_of_string s); Some sl)
                  with | Invalid_argument "bool_of_string" -> None)
             | [] -> None)
          else
            (try (f (bool_of_string s); Some sl)
             with | Invalid_argument "bool_of_string" -> None)
      | Arg.Set r -> if s = "" then (r := true; Some sl) else None
      | Arg.Clear r -> if s = "" then (r := false; Some sl) else None
      | Arg.Rest f -> (List.iter f (s :: sl); Some [])
      | Arg.String f ->
          if s = ""
          then (match sl with | s :: sl -> (f s; Some sl) | [] -> None)
          else (f s; Some sl)
      | Arg.Set_string r ->
          if s = ""
          then (match sl with | s :: sl -> (r := s; Some sl) | [] -> None)
          else (r := s; Some sl)
      | Arg.Int f ->
          if s = ""
          then
            (match sl with
             | s :: sl ->
                 (try (f (int_of_string s); Some sl)
                  with | Failure "int_of_string" -> None)
             | [] -> None)
          else
            (try (f (int_of_string s); Some sl)
             with | Failure "int_of_string" -> None)
      | Arg.Set_int r ->
          if s = ""
          then
            (match sl with
             | s :: sl ->
                 (try (r := int_of_string s; Some sl)
                  with | Failure "int_of_string" -> None)
             | [] -> None)
          else
            (try (r := int_of_string s; Some sl)
             with | Failure "int_of_string" -> None)
      | Arg.Float f ->
          if s = ""
          then
            (match sl with
             | s :: sl -> (f (float_of_string s); Some sl)
             | [] -> None)
          else (f (float_of_string s); Some sl)
      | Arg.Set_float r ->
          if s = ""
          then
            (match sl with
             | s :: sl -> (r := float_of_string s; Some sl)
             | [] -> None)
          else (r := float_of_string s; Some sl)
      | Arg.Tuple specs ->
          let rec action_args s sl =
            (function
             | [] -> Some sl
             | spec :: spec_list ->
                 (match action_arg s sl spec with
                  | None -> action_args "" [] spec_list
                  | Some (s :: sl) -> action_args s sl spec_list
                  | Some sl -> action_args "" sl spec_list))
          in action_args s sl specs
      | Arg.Symbol (syms, f) ->
          (match if s = "" then sl else s :: sl with
           | s :: sl when List.mem s syms -> (f s; Some sl)
           | _ -> None)
    let common_start s1 s2 =
      let rec loop i =
        if (i == (String.length s1)) || (i == (String.length s2))
        then i
        else if s1.[i] == s2.[i] then loop (i + 1) else i
      in loop 0
    let parse_arg fold s sl =
      fold
        (fun (name, action, _) acu ->
           let i = common_start s name
           in
             if i == (String.length name)
             then
               (try
                  action_arg (String.sub s i ((String.length s) - i)) sl
                    action
                with | Arg.Bad _ -> acu)
             else acu)
        None
    let rec parse_aux fold anon_fun =
      function
      | [] -> []
      | s :: sl ->
          if ((String.length s) > 1) && (s.[0] = '-')
          then
            (match parse_arg fold s sl with
             | Some sl -> parse_aux fold anon_fun sl
             | None -> s :: (parse_aux fold anon_fun sl))
          else ((anon_fun s : unit); parse_aux fold anon_fun sl)
    let align_doc key s =
      let s =
        let rec loop i =
          if i = (String.length s)
          then ""
          else
            if s.[i] = ' '
            then loop (i + 1)
            else String.sub s i ((String.length s) - i)
        in loop 0 in
      let (p, s) =
        if (String.length s) > 0
        then
          if s.[0] = '<'
          then
            (let rec loop i =
               if i = (String.length s)
               then ("", s)
               else
                 if s.[i] <> '>'
                 then loop (i + 1)
                 else
                   (let p = String.sub s 0 (i + 1) in
                    let rec loop i =
                      if i >= (String.length s)
                      then (p, "")
                      else
                        if s.[i] = ' '
                        then loop (i + 1)
                        else (p, (String.sub s i ((String.length s) - i)))
                    in loop (i + 1))
             in loop 0)
          else ("", s)
        else ("", "") in
      let tab =
        String.make (max 1 ((16 - (String.length key)) - (String.length p)))
          ' '
      in p ^ (tab ^ s)
    let make_symlist l =
      match l with
      | [] -> "<none>"
      | h :: t ->
          (List.fold_left (fun x y -> x ^ ("|" ^ y)) ("{" ^ h) t) ^ "}"
    let print_usage_list l =
      List.iter
        (fun (key, spec, doc) ->
           match spec with
           | Arg.Symbol (symbs, _) ->
               let s = make_symlist symbs in
               let synt = key ^ (" " ^ s)
               in eprintf "  %s %s\n" synt (align_doc synt doc)
           | _ -> eprintf "  %s %s\n" key (align_doc key doc))
        l
    let remaining_args argv =
      let rec loop l i =
        if i == (Array.length argv) then l else loop (argv.(i) :: l) (i + 1)
      in List.rev (loop [] (!Arg.current + 1))
    let init_spec_list = ref []
    let ext_spec_list = ref []
    let init spec_list = init_spec_list := spec_list
    let add name spec descr =
      ext_spec_list := (name, spec, descr) :: !ext_spec_list
    let fold f init =
      let spec_list = !init_spec_list @ !ext_spec_list in
      let specs = Sort.list (fun (k1, _, _) (k2, _, _) -> k1 >= k2) spec_list
      in List.fold_right f specs init
    let parse anon_fun argv =
      let remaining_args = remaining_args argv
      in parse_aux fold anon_fun remaining_args
    let ext_spec_list () = !ext_spec_list
  end
module Sig =
  struct
    (* camlp4r *)
    (****************************************************************************)
    (*                                                                          *)
    (*                              Objective Caml                              *)
    (*                                                                          *)
    (*                            INRIA Rocquencourt                            *)
    (*                                                                          *)
    (*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
    (*  en Automatique.  All rights reserved.  This file is distributed under   *)
    (*  the terms of the GNU Library General Public License, with the special   *)
    (*  exception on linking described in LICENSE at the top of the Objective   *)
    (*  Caml source tree.                                                       *)
    (*                                                                          *)
    (****************************************************************************)
    (* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)
    module type Type = sig type t end
    (** Signature for errors modules, an Error modules can be registred with
    the {!ErrorHandler.Register} functor in order to be well printed. *)
    module type Error =
      sig
        type t
        exception E of t
        val to_string : t -> string
        val print : Format.formatter -> t -> unit
      end
    (** A signature for extensions identifiers. *)
    module type Id =
      sig
        (** The name of the extension, typically the module name. *)
        val name : string
        (** The version of the extension, typically $Id: Id.mli,v 1.2 2006/07/08 17:21:31 pouillar Exp $ with a versionning system. *)
        val version : string
      end
    module type Loc =
      sig
        type t
        (** Return a start location for the given file name.
      This location starts at the begining of the file. *)
        val mk : string -> t
        (** The [ghost] location can be used when no location
      information is available. *)
        val ghost : t
        (** {6 Conversion functions} *)
        (** Return a location where both positions are set the given position. *)
        val of_lexing_position : Lexing.position -> t
        (** Return an OCaml location. *)
        val to_ocaml_location : t -> Location.t
        (** Return a location from an OCaml location. *)
        val of_ocaml_location : Location.t -> t
        (** Return a location from ocamllex buffer. *)
        val of_lexbuf : Lexing.lexbuf -> t
        (** Return a location from [(file_name, start_line, start_bol, start_off,
      stop_line,  stop_bol,  stop_off, ghost)]. *)
        val of_tuple :
          (string * int * int * int * int * int * int * bool) -> t
        (** Return [(file_name, start_line, start_bol, start_off,
      stop_line,  stop_bol,  stop_off, ghost)]. *)
        val to_tuple :
          t -> (string * int * int * int * int * int * int * bool)
        (** [merge loc1 loc2] Return a location that starts at [loc1] and end at [loc2]. *)
        val merge : t -> t -> t
        (** The stop pos becomes equal to the start pos. *)
        val join : t -> t
        (** [move selector n loc]
      Return the location where positions are moved.
      Affected positions are chosen with [selector].
      Returned positions have their character offset plus [n]. *)
        val move : [ `start | `stop | `both ] -> int -> t -> t
        (** [shift n loc] Return the location where the new start position is the old
      stop position, and where the new stop position character offset is the
      old one plus [n]. *)
        val shift : int -> t -> t
        (** [move_line n loc] Return the location with the old line count plus [n].
      The "begin of line" of both positions become the current offset. *)
        val move_line : int -> t -> t
        (** Accessors *)
        (** Return the file name *)
        val file_name : t -> string
        (** Return the line number of the begining of this location. *)
        val start_line : t -> int
        (** Return the line number of the ending of this location. *)
        val stop_line : t -> int
        (** Returns the number of characters from the begining of the file
      to the begining of the line of location's begining. *)
        val start_bol : t -> int
        (** Returns the number of characters from the begining of the file
      to the begining of the line of location's ending. *)
        val stop_bol : t -> int
        (** Returns the number of characters from the begining of the file
      of the begining of this location. *)
        val start_off : t -> int
        (** Return the number of characters from the begining of the file
      of the ending of this location. *)
        val stop_off : t -> int
        (** Return the start position as a Lexing.position. *)
        val start_pos : t -> Lexing.position
        (** Return the stop position as a Lexing.position. *)
        val stop_pos : t -> Lexing.position
        (** Generally, return true if this location does not come
      from an input stream. *)
        val is_ghost : t -> bool
        (** Return the associated ghost location. *)
        val ghostify : t -> t
        (** Return the location with the give file name *)
        val set_file_name : string -> t -> t
        (** [strictly_before loc1 loc2] True if the stop position of [loc1] is
      strictly_before the start position of [loc2]. *)
        val strictly_before : t -> t -> bool
        (** Return the location with an absolute file name. *)
        val make_absolute : t -> t
        (** Print the location into the formatter in a format suitable for error
      reporting. *)
        val print : Format.formatter -> t -> unit
        (** Print the location in a short format useful for debugging. *)
        val dump : Format.formatter -> t -> unit
        (** Same as {!print} but return a string instead of printting it. *)
        val to_string : t -> string
        (** [Exc_located loc e] is an encapsulation of the exception [e] with
      the input location [loc]. To be used in quotation expanders
      and in grammars to specify some input location for an error.
      Do not raise this exception directly: rather use the following
      function [Loc.raise]. *)
        exception Exc_located of t * exn
        (** [raise loc e], if [e] is already an [Exc_located] exception,
      re-raise it, else raise the exception [Exc_located loc e]. *)
        val raise : t -> exn -> 'a
        (** The name of the location variable used in grammars and in
      the predefined quotations for OCaml syntax trees. Default: [_loc]. *)
        val name : string ref
      end
    module type Warning =
      sig
        module Loc : Loc
        type t = Loc.t -> string -> unit
        val default : t
        val current : t ref
        val print : t
      end
    (** Base class for map traversal, it includes some builtin types. *)
    class mapper =
      (object method string = fun x -> (x : string)
         method int = fun x -> (x : int)
         method float = fun x -> (x : float)
         method bool = fun x -> (x : bool)
         method list : 'a 'b. ('a -> 'b) -> 'a list -> 'b list = List.map
         method option : 'a 'b. ('a -> 'b) -> 'a option -> 'b option =
           fun f -> function | None -> None | Some x -> Some (f x)
         method array : 'a 'b. ('a -> 'b) -> 'a array -> 'b array = Array.map
         method ref : 'a 'b. ('a -> 'b) -> 'a ref -> 'b ref =
           fun f { contents = x } -> {  contents = f x; }
       end :
       object
         method string : string -> string
         method int : int -> int
         method float : float -> float
         method bool : bool -> bool
         method list : 'a 'b. ('a -> 'b) -> 'a list -> 'b list
         method option : 'a 'b. ('a -> 'b) -> 'a option -> 'b option
         method array : 'a 'b. ('a -> 'b) -> 'a array -> 'b array
         method ref : 'a 'b. ('a -> 'b) -> 'a ref -> 'b ref
       end)
    (** Abstract syntax tree minimal signature.
    Types of this signature are abstract.
    See the {!Camlp4Ast} signature for a concrete definition. *)
    module type Ast =
      sig
        module Loc : Loc
        type meta_bool
        type 'a meta_option
        type ctyp
        type patt
        type expr
        type module_type
        type sig_item
        type with_constr
        type module_expr
        type str_item
        type class_type
        type class_sig_item
        type class_expr
        type class_str_item
        type match_case
        type ident
        type binding
        type module_binding
        val loc_of_ctyp : ctyp -> Loc.t
        val loc_of_patt : patt -> Loc.t
        val loc_of_expr : expr -> Loc.t
        val loc_of_module_type : module_type -> Loc.t
        val loc_of_module_expr : module_expr -> Loc.t
        val loc_of_sig_item : sig_item -> Loc.t
        val loc_of_str_item : str_item -> Loc.t
        val loc_of_class_type : class_type -> Loc.t
        val loc_of_class_sig_item : class_sig_item -> Loc.t
        val loc_of_class_expr : class_expr -> Loc.t
        val loc_of_class_str_item : class_str_item -> Loc.t
        val loc_of_with_constr : with_constr -> Loc.t
        val loc_of_binding : binding -> Loc.t
        val loc_of_module_binding : module_binding -> Loc.t
        val loc_of_match_case : match_case -> Loc.t
        val loc_of_ident : ident -> Loc.t
        (** This class is the base class for map traversal on the Ast.
      To make a custom traversal class one just extend it like that:
      
      This example swap pairs expression contents:
      open Camlp4.PreCast;
      [class swap = object
        inherit Ast.map as super;
        method expr e =
          match super#expr e with
          \[ <:expr\@_loc< ($e1$, $e2$) >> -> <:expr< ($e2$, $e1$) >>
          | e -> e \];
      end;
      value _loc = Loc.ghost;
      value map = (new swap)#expr;
      assert (map <:expr< fun x -> (x, 42) >> = <:expr< fun x -> (42, x) >>);]
  *)
        class map :
          object
            inherit mapper
            method meta_bool : meta_bool -> meta_bool
            method meta_option :
              'a 'b. ('a -> 'b) -> 'a meta_option -> 'b meta_option
            method _Loc_t : Loc.t -> Loc.t
            method expr : expr -> expr
            method patt : patt -> patt
            method ctyp : ctyp -> ctyp
            method str_item : str_item -> str_item
            method sig_item : sig_item -> sig_item
            method module_expr : module_expr -> module_expr
            method module_type : module_type -> module_type
            method class_expr : class_expr -> class_expr
            method class_type : class_type -> class_type
            method class_sig_item : class_sig_item -> class_sig_item
            method class_str_item : class_str_item -> class_str_item
            method with_constr : with_constr -> with_constr
            method binding : binding -> binding
            method module_binding : module_binding -> module_binding
            method match_case : match_case -> match_case
            method ident : ident -> ident
          end
        class fold :
          object ('self_type)
            method string : string -> 'self_type
            method int : int -> 'self_type
            method float : float -> 'self_type
            method bool : bool -> 'self_type
            method list :
              'a. ('self_type -> 'a -> 'self_type) -> 'a list -> 'self_type
            method option :
              'a. ('self_type -> 'a -> 'self_type) -> 'a option -> 'self_type
            method array :
              'a. ('self_type -> 'a -> 'self_type) -> 'a array -> 'self_type
            method ref :
              'a. ('self_type -> 'a -> 'self_type) -> 'a ref -> 'self_type
            method meta_bool : meta_bool -> 'self_type
            method meta_option :
              'a.
                ('self_type -> 'a -> 'self_type) ->
                  'a meta_option -> 'self_type
            method _Loc_t : Loc.t -> 'self_type
            method expr : expr -> 'self_type
            method patt : patt -> 'self_type
            method ctyp : ctyp -> 'self_type
            method str_item : str_item -> 'self_type
            method sig_item : sig_item -> 'self_type
            method module_expr : module_expr -> 'self_type
            method module_type : module_type -> 'self_type
            method class_expr : class_expr -> 'self_type
            method class_type : class_type -> 'self_type
            method class_sig_item : class_sig_item -> 'self_type
            method class_str_item : class_str_item -> 'self_type
            method with_constr : with_constr -> 'self_type
            method binding : binding -> 'self_type
            method module_binding : module_binding -> 'self_type
            method match_case : match_case -> 'self_type
            method ident : ident -> 'self_type
          end
      end
    (** The AntiquotSyntax signature describe the minimal interface needed
    for antiquotation handling. *)
    module type AntiquotSyntax =
      sig
        module Ast : Ast
        (** The parse function for expressions.
      The underlying expression grammar entry is generally "expr; EOI". *)
        val parse_expr : Ast.Loc.t -> string -> Ast.expr
        (** The parse function for patterns.
      The underlying pattern grammar entry is generally "patt; EOI". *)
        val parse_patt : Ast.Loc.t -> string -> Ast.patt
      end
    (** Signature for OCaml syntax trees.
    This signature is an extension of {!Ast}
    It provides:
      - Types for all kinds of structure.
      - Map: A base class for map traversals.
      - Map classes and functions for common kinds. *)
    module type Camlp4Ast =
      sig
        module Loc : Loc
        type meta_bool = | BTrue | BFalse | BAnt of string
        type 'a meta_option = | ONone | OSome of 'a | OAnt of string
        type ident =
          | IdAcc of Loc.t * ident * ident | (* i . i *)
          IdApp of Loc.t * ident * ident | (* i i *) IdLid of Loc.t * string
          | (* foo *) IdUid of Loc.t * string | (* Bar *)
          IdAnt of Loc.t * string
        (* $s$ *)
        type ctyp =
          | TyNil of Loc.t | TyAli of Loc.t * ctyp * ctyp | (* t as t *)
          (* list 'a as 'a *) TyAny of Loc.t | (* _ *)
          TyApp of Loc.t * ctyp * ctyp | (* t t *) (* list 'a *)
          TyArr of Loc.t * ctyp * ctyp | (* t -> t *) (* int -> string *)
          TyCls of Loc.t * ident | (* #i *) (* #point *)
          TyLab of Loc.t * string * ctyp | (* ~s *) TyId of Loc.t * ident
          | (* i *) (* Lazy.t *) TyMan of Loc.t * ctyp * ctyp | (* t == t *)
          (* type t = [ A | B ] == Foo.t *)
          (* type t 'a 'b 'c = t constraint t = t constraint t = t *)
          TyDcl of Loc.t * string * ctyp list * ctyp * (ctyp * ctyp) list
          | (* < (t)? (..)? > *) (* < move : int -> 'a .. > as 'a  *)
          TyObj of Loc.t * ctyp * meta_bool | TyOlb of Loc.t * string * ctyp
          | (* ?s *) TyPol of Loc.t * ctyp * ctyp | (* ! t . t *)
          (* ! 'a . list 'a -> 'a *) TyQuo of Loc.t * string | (* 's *)
          TyQuP of Loc.t * string | (* +'s *) TyQuM of Loc.t * string
          | (* -'s *) TyVrn of Loc.t * string | (* `s *)
          TyRec of Loc.t * ctyp | (* { t } *)
          (* { foo : int ; bar : mutable string } *)
          TyCol of Loc.t * ctyp * ctyp | (* t : t *)
          TySem of Loc.t * ctyp * ctyp | (* t; t *)
          TyCom of Loc.t * ctyp * ctyp | (* t, t *) TySum of Loc.t * ctyp
          | (* [ t ] *) (* [ A of int and string | B ] *)
          TyOf of Loc.t * ctyp * ctyp | (* t of t *) (* A of int *)
          TyAnd of Loc.t * ctyp * ctyp | (* t and t *)
          TyOr of Loc.t * ctyp * ctyp | (* t | t *) TyPrv of Loc.t * ctyp
          | (* private t *) TyMut of Loc.t * ctyp | (* mutable t *)
          TyTup of Loc.t * ctyp | (* ( t ) *) (* (int * string) *)
          TySta of Loc.t * ctyp * ctyp | (* t * t *) TyVrnEq of Loc.t * ctyp
          | (* [ = t ] *) TyVrnSup of Loc.t * ctyp | (* [ > t ] *)
          TyVrnInf of Loc.t * ctyp | (* [ < t ] *)
          TyVrnInfSup of Loc.t * ctyp * ctyp | (* [ < t > t ] *)
          TyAmp of Loc.t * ctyp * ctyp | (* t & t *)
          TyOfAmp of Loc.t * ctyp * ctyp | (* t of & t *)
          TyAnt of Loc.t * string
        (* $s$ *)
        type (* i *)
          (* p as p *)
          (* (Node x y as n) *)
          (* $s$ *)
          (* _ *)
          (* p p *)
          (* fun x y -> *)
          (* [| p |] *)
          (* p, p *)
          (* p; p *)
          (* c *)
          (* 'x' *)
          (* ~s or ~s:(p) *)
          (* ?s or ?s:(p = e) or ?(p = e) *)
          (* | PaOlb of Loc.t and string and meta_option(*FIXME*) (patt * meta_option(*FIXME*) expr) *)
          (* ?s or ?s:(p) *)
          (* ?s:(p = e) or ?(p = e) *)
          (* p | p *)
          (* p .. p *)
          (* { p } *)
          (* p = p *)
          (* s *)
          (* ( p ) *)
          (* (p : t) *)
          (* #i *)
          (* `s *)
          (* i *)
          (* e.e *)
          (* $s$ *)
          (* e e *)
          (* e.(e) *)
          (* [| e |] *)
          (* e; e *)
          (* assert False *)
          (* assert e *)
          (* e := e *)
          (* 'c' *)
          (* (e : t) or (e : t :> t) *)
          (* 3.14 *)
          (* for s = e to/downto e do { e } *)
          (* fun [ a ] *)
          (* if e then e else e *)
          (* 42 *)
          (* ~s or ~s:e *)
          (* lazy e *)
          (* let b in e or let rec b in e *)
          (* let module s = me in e *)
          (* match e with [ a ] *)
          (* new i *)
          (* object ((p))? (cst)? end *)
          (* ?s or ?s:e *)
          (* {< b >} *)
          (* { b } or { (e) with b } *)
          (* do { e } *)
          (* e#s *)
          (* e.[e] *)
          (* s *)
          (* "foo" *)
          (* try e with [ a ] *)
          (* (e) *)
          (* e, e *)
          (* (e : t) *)
          (* `s *)
          (* while e do { e } *)
          (* i *)
          (* A.B.C *)
          (* functor (s : mt) -> mt *)
          (* 's *)
          (* sig (sg)? end *)
          (* mt with wc *)
          (* $s$ *)
          (* class cict *)
          (* class type cict *)
          (* sg ; sg *)
          (* # s or # s e *)
          (* exception t *)
          (* |+ external s : t = s ... s +|
    | SgExt of Loc.t and string and ctyp and list string    *)
          (* external s : t = s *)
          (* include mt *)
          (* module s : mt *)
          (* module rec mb *)
          (* module type s = mt *)
          (* open i *)
          (* type t *)
          (* value s : t *)
          (* $s$ *)
          (* type t = t *)
          (* module i = i *)
          (* wc and wc *)
          (* $s$ *)
          (* b and b *)
          (* let a = 42 and c = 43 *)
          (* b ; b *)
          (* p = e *)
          (* let patt = expr *)
          (* $s$ *)
          (* mb and mb *)
          (* module rec (s : mt) = me and (s : mt) = me *)
          (* s : mt = me *)
          (* s : mt *)
          (* $s$ *)
          (* a | a *)
          (* p (when e)? -> e *)
          (* $s$ *)
          (* i *)
          (* me me *)
          (* functor (s : mt) -> me *)
          (* struct (st)? end *)
          (* (me : mt) *)
          (* $s$ *)
          (* class cice *)
          (* class type cict *)
          (* st ; st *)
          (* # s or # s e *)
          (* exception t or exception t = i *)
          (*FIXME*)
          (* e *)
          (* |+ external s : t = s ... s +|
    | StExt of Loc.t and string and ctyp and list string    *)
          (* external s : t = s *)
          (* include me *)
          (* module s = me *)
          (* module rec mb *)
          (* module type s = mt *)
          (* open i *)
          (* type t *)
          (* value b or value rec b *)
          (* $s$ *)
          (* (virtual)? i ([ t ])? *)
          (* [t] -> ct *)
          (* object ((t))? (csg)? end *)
          (* ct and ct *)
          (* ct : ct *)
          (* ct = ct *)
          (* $s$ *)
          (* type t = t *)
          (* csg ; csg *)
          (* inherit ct *)
          (* method s : t or method private s : t *)
          (* value (virtual)? (mutable)? s : t *)
          (* method virtual (mutable)? s : t *)
          (* $s$ *)
          (* ce e *)
          (* (virtual)? i ([ t ])? *)
          (* fun p -> ce *)
          (* let (rec)? b in ce *)
          (* object ((p))? (cst)? end *)
          (* ce : ct *)
          (* ce and ce *)
          (* ce = ce *)
          (* $s$ *)
          patt =
          | PaNil of Loc.t | PaId of Loc.t * ident
          | PaAli of Loc.t * patt * patt | PaAnt of Loc.t * string
          | PaAny of Loc.t | PaApp of Loc.t * patt * patt
          | PaArr of Loc.t * patt | PaCom of Loc.t * patt * patt
          | PaSem of Loc.t * patt * patt | PaChr of Loc.t * string
          | PaInt of Loc.t * string | PaInt32 of Loc.t * string
          | PaInt64 of Loc.t * string | PaNativeInt of Loc.t * string
          | PaFlo of Loc.t * string | PaLab of Loc.t * string * patt
          | PaOlb of Loc.t * string * patt
          | PaOlbi of Loc.t * string * patt * expr
          | PaOrp of Loc.t * patt * patt | PaRng of Loc.t * patt * patt
          | PaRec of Loc.t * patt | PaEq of Loc.t * patt * patt
          | PaStr of Loc.t * string | PaTup of Loc.t * patt
          | PaTyc of Loc.t * patt * ctyp | PaTyp of Loc.t * ident
          | PaVrn of Loc.t * string
          and expr =
          | ExNil of Loc.t | ExId of Loc.t * ident
          | ExAcc of Loc.t * expr * expr | ExAnt of Loc.t * string
          | ExApp of Loc.t * expr * expr | ExAre of Loc.t * expr * expr
          | ExArr of Loc.t * expr | ExSem of Loc.t * expr * expr
          | ExAsf of Loc.t | ExAsr of Loc.t * expr
          | ExAss of Loc.t * expr * expr | ExChr of Loc.t * string
          | ExCoe of Loc.t * expr * ctyp * ctyp | ExFlo of Loc.t * string
          | ExFor of Loc.t * string * expr * expr * meta_bool * expr
          | ExFun of Loc.t * match_case | ExIfe of Loc.t * expr * expr * expr
          | ExInt of Loc.t * string | ExInt32 of Loc.t * string
          | ExInt64 of Loc.t * string | ExNativeInt of Loc.t * string
          | ExLab of Loc.t * string * expr | ExLaz of Loc.t * expr
          | ExLet of Loc.t * meta_bool * binding * expr
          | ExLmd of Loc.t * string * module_expr * expr
          | ExMat of Loc.t * expr * match_case | ExNew of Loc.t * ident
          | ExObj of Loc.t * patt * class_str_item
          | ExOlb of Loc.t * string * expr | ExOvr of Loc.t * binding
          | ExRec of Loc.t * binding * expr | ExSeq of Loc.t * expr
          | ExSnd of Loc.t * expr * string | ExSte of Loc.t * expr * expr
          | ExStr of Loc.t * string | ExTry of Loc.t * expr * match_case
          | ExTup of Loc.t * expr | ExCom of Loc.t * expr * expr
          | ExTyc of Loc.t * expr * ctyp | ExVrn of Loc.t * string
          | ExWhi of Loc.t * expr * expr
          and module_type =
          | MtId of Loc.t * ident
          | MtFun of Loc.t * string * module_type * module_type
          | MtQuo of Loc.t * string | MtSig of Loc.t * sig_item
          | MtWit of Loc.t * module_type * with_constr
          | MtAnt of Loc.t * string
          and sig_item =
          | SgNil of Loc.t | SgCls of Loc.t * class_type
          | SgClt of Loc.t * class_type
          | SgSem of Loc.t * sig_item * sig_item
          | SgDir of Loc.t * string * expr | SgExc of Loc.t * ctyp
          | SgExt of Loc.t * string * ctyp * string
          | SgInc of Loc.t * module_type
          | SgMod of Loc.t * string * module_type
          | SgRecMod of Loc.t * module_binding
          | SgMty of Loc.t * string * module_type | SgOpn of Loc.t * ident
          | SgTyp of Loc.t * ctyp | SgVal of Loc.t * string * ctyp
          | SgAnt of Loc.t * string
          and with_constr =
          | WcNil of Loc.t | WcTyp of Loc.t * ctyp * ctyp
          | WcMod of Loc.t * ident * ident
          | WcAnd of Loc.t * with_constr * with_constr
          | WcAnt of Loc.t * string
          and binding =
          | BiNil of Loc.t | BiAnd of Loc.t * binding * binding
          | BiSem of Loc.t * binding * binding | BiEq of Loc.t * patt * expr
          | BiAnt of Loc.t * string
          and module_binding =
          | MbNil of Loc.t | MbAnd of Loc.t * module_binding * module_binding
          | MbColEq of Loc.t * string * module_type * module_expr
          | MbCol of Loc.t * string * module_type | MbAnt of Loc.t * string
          and match_case =
          | McNil of Loc.t | McOr of Loc.t * match_case * match_case
          | McArr of Loc.t * patt * expr * expr | McAnt of Loc.t * string
          and module_expr =
          | MeId of Loc.t * ident
          | MeApp of Loc.t * module_expr * module_expr
          | MeFun of Loc.t * string * module_type * module_expr
          | MeStr of Loc.t * str_item
          | MeTyc of Loc.t * module_expr * module_type
          | MeAnt of Loc.t * string
          and str_item =
          | StNil of Loc.t | StCls of Loc.t * class_expr
          | StClt of Loc.t * class_type
          | StSem of Loc.t * str_item * str_item
          | StDir of Loc.t * string * expr
          | StExc of Loc.t * ctyp * ident meta_option | StExp of Loc.t * expr
          | StExt of Loc.t * string * ctyp * string
          | StInc of Loc.t * module_expr
          | StMod of Loc.t * string * module_expr
          | StRecMod of Loc.t * module_binding
          | StMty of Loc.t * string * module_type | StOpn of Loc.t * ident
          | StTyp of Loc.t * ctyp | StVal of Loc.t * meta_bool * binding
          | StAnt of Loc.t * string
          and class_type =
          | CtNil of Loc.t | CtCon of Loc.t * meta_bool * ident * ctyp
          | CtFun of Loc.t * ctyp * class_type
          | CtSig of Loc.t * ctyp * class_sig_item
          | CtAnd of Loc.t * class_type * class_type
          | CtCol of Loc.t * class_type * class_type
          | CtEq of Loc.t * class_type * class_type | CtAnt of Loc.t * string
          and class_sig_item =
          | CgNil of Loc.t | CgCtr of Loc.t * ctyp * ctyp
          | CgSem of Loc.t * class_sig_item * class_sig_item
          | CgInh of Loc.t * class_type
          | CgMth of Loc.t * string * meta_bool * ctyp
          | CgVal of Loc.t * string * meta_bool * meta_bool * ctyp
          | CgVir of Loc.t * string * meta_bool * ctyp
          | CgAnt of Loc.t * string
          and class_expr =
          | CeNil of Loc.t | CeApp of Loc.t * class_expr * expr
          | CeCon of Loc.t * meta_bool * ident * ctyp
          | CeFun of Loc.t * patt * class_expr
          | CeLet of Loc.t * meta_bool * binding * class_expr
          | CeStr of Loc.t * patt * class_str_item
          | CeTyc of Loc.t * class_expr * class_type
          | CeAnd of Loc.t * class_expr * class_expr
          | CeEq of Loc.t * class_expr * class_expr | CeAnt of Loc.t * string
          and class_str_item =
          | CrNil of Loc.t | (* cst ; cst *)
          CrSem of Loc.t * class_str_item * class_str_item | (* type t = t *)
          CrCtr of Loc.t * ctyp * ctyp | (* inherit ce or inherit ce as s *)
          CrInh of Loc.t * class_expr * string | (* initializer e *)
          CrIni of Loc.t * expr
          | (* method (private)? s : t = e or method (private)? s = e *)
          CrMth of Loc.t * string * meta_bool * expr * ctyp
          | (* value (mutable)? s = e *)
          CrVal of Loc.t * string * meta_bool * expr
          | (* method virtual (private)? s : t *)
          CrVir of Loc.t * string * meta_bool * ctyp
          | (* value virtual (private)? s : t *)
          CrVvr of Loc.t * string * meta_bool * ctyp
          | CrAnt of Loc.t * string
        val loc_of_ctyp : ctyp -> Loc.t
        val loc_of_patt : patt -> Loc.t
        val loc_of_expr : expr -> Loc.t
        val loc_of_module_type : module_type -> Loc.t
        val loc_of_module_expr : module_expr -> Loc.t
        val loc_of_sig_item : sig_item -> Loc.t
        val loc_of_str_item : str_item -> Loc.t
        val loc_of_class_type : class_type -> Loc.t
        val loc_of_class_sig_item : class_sig_item -> Loc.t
        val loc_of_class_expr : class_expr -> Loc.t
        val loc_of_class_str_item : class_str_item -> Loc.t
        val loc_of_with_constr : with_constr -> Loc.t
        val loc_of_binding : binding -> Loc.t
        val loc_of_module_binding : module_binding -> Loc.t
        val loc_of_match_case : match_case -> Loc.t
        val loc_of_ident : ident -> Loc.t
        module Meta :
          sig
            module type META_LOC =
              sig
                val meta_loc_patt : Loc.t -> Loc.t -> patt
                val meta_loc_expr : Loc.t -> Loc.t -> expr
              end
            module MetaLoc :
              sig
                val meta_loc_patt : Loc.t -> Loc.t -> patt
                val meta_loc_expr : Loc.t -> Loc.t -> expr
              end
            module MetaGhostLoc :
              sig
                val meta_loc_patt : Loc.t -> 'a -> patt
                val meta_loc_expr : Loc.t -> 'a -> expr
              end
            module MetaLocVar :
              sig
                val meta_loc_patt : Loc.t -> 'a -> patt
                val meta_loc_expr : Loc.t -> 'a -> expr
              end
            module Make (MetaLoc : META_LOC) :
              sig
                module Expr :
                  sig
                    val meta_string : Loc.t -> string -> expr
                    val meta_int : Loc.t -> string -> expr
                    val meta_float : Loc.t -> string -> expr
                    val meta_char : Loc.t -> string -> expr
                    val meta_bool : Loc.t -> bool -> expr
                    val meta_list :
                      (Loc.t -> 'a -> expr) -> Loc.t -> 'a list -> expr
                    val meta_binding : Loc.t -> binding -> expr
                    val meta_class_expr : Loc.t -> class_expr -> expr
                    val meta_class_sig_item : Loc.t -> class_sig_item -> expr
                    val meta_class_str_item : Loc.t -> class_str_item -> expr
                    val meta_class_type : Loc.t -> class_type -> expr
                    val meta_ctyp : Loc.t -> ctyp -> expr
                    val meta_expr : Loc.t -> expr -> expr
                    val meta_ident : Loc.t -> ident -> expr
                    val meta_match_case : Loc.t -> match_case -> expr
                    val meta_meta_bool : Loc.t -> meta_bool -> expr
                    val meta_meta_option :
                      (Loc.t -> ident -> expr) ->
                        Loc.t -> ident meta_option -> expr
                    val meta_module_binding : Loc.t -> module_binding -> expr
                    val meta_module_expr : Loc.t -> module_expr -> expr
                    val meta_module_type : Loc.t -> module_type -> expr
                    val meta_patt : Loc.t -> patt -> expr
                    val meta_sig_item : Loc.t -> sig_item -> expr
                    val meta_str_item : Loc.t -> str_item -> expr
                    val meta_with_constr : Loc.t -> with_constr -> expr
                  end
                module Patt :
                  sig
                    val meta_string : Loc.t -> string -> patt
                    val meta_int : Loc.t -> string -> patt
                    val meta_float : Loc.t -> string -> patt
                    val meta_char : Loc.t -> string -> patt
                    val meta_bool : Loc.t -> bool -> patt
                    val meta_list :
                      (Loc.t -> 'a -> patt) -> Loc.t -> 'a list -> patt
                    val meta_binding : Loc.t -> binding -> patt
                    val meta_class_expr : Loc.t -> class_expr -> patt
                    val meta_class_sig_item : Loc.t -> class_sig_item -> patt
                    val meta_class_str_item : Loc.t -> class_str_item -> patt
                    val meta_class_type : Loc.t -> class_type -> patt
                    val meta_ctyp : Loc.t -> ctyp -> patt
                    val meta_expr : Loc.t -> expr -> patt
                    val meta_ident : Loc.t -> ident -> patt
                    val meta_match_case : Loc.t -> match_case -> patt
                    val meta_meta_bool : Loc.t -> meta_bool -> patt
                    val meta_meta_option :
                      (Loc.t -> ident -> patt) ->
                        Loc.t -> ident meta_option -> patt
                    val meta_module_binding : Loc.t -> module_binding -> patt
                    val meta_module_expr : Loc.t -> module_expr -> patt
                    val meta_module_type : Loc.t -> module_type -> patt
                    val meta_patt : Loc.t -> patt -> patt
                    val meta_sig_item : Loc.t -> sig_item -> patt
                    val meta_str_item : Loc.t -> str_item -> patt
                    val meta_with_constr : Loc.t -> with_constr -> patt
                  end
              end
          end
        class map :
          object
            inherit mapper
            method meta_bool : meta_bool -> meta_bool
            method meta_option :
              'a 'b. ('a -> 'b) -> 'a meta_option -> 'b meta_option
            method _Loc_t : Loc.t -> Loc.t
            method expr : expr -> expr
            method patt : patt -> patt
            method ctyp : ctyp -> ctyp
            method str_item : str_item -> str_item
            method sig_item : sig_item -> sig_item
            method module_expr : module_expr -> module_expr
            method module_type : module_type -> module_type
            method class_expr : class_expr -> class_expr
            method class_type : class_type -> class_type
            method class_sig_item : class_sig_item -> class_sig_item
            method class_str_item : class_str_item -> class_str_item
            method with_constr : with_constr -> with_constr
            method binding : binding -> binding
            method module_binding : module_binding -> module_binding
            method match_case : match_case -> match_case
            method ident : ident -> ident
          end
        class fold :
          object ('self_type)
            method string : string -> 'self_type
            method int : int -> 'self_type
            method float : float -> 'self_type
            method bool : bool -> 'self_type
            method list :
              'a. ('self_type -> 'a -> 'self_type) -> 'a list -> 'self_type
            method option :
              'a. ('self_type -> 'a -> 'self_type) -> 'a option -> 'self_type
            method array :
              'a. ('self_type -> 'a -> 'self_type) -> 'a array -> 'self_type
            method ref :
              'a. ('self_type -> 'a -> 'self_type) -> 'a ref -> 'self_type
            method meta_bool : meta_bool -> 'self_type
            method meta_option :
              'a.
                ('self_type -> 'a -> 'self_type) ->
                  'a meta_option -> 'self_type
            method _Loc_t : Loc.t -> 'self_type
            method expr : expr -> 'self_type
            method patt : patt -> 'self_type
            method ctyp : ctyp -> 'self_type
            method str_item : str_item -> 'self_type
            method sig_item : sig_item -> 'self_type
            method module_expr : module_expr -> 'self_type
            method module_type : module_type -> 'self_type
            method class_expr : class_expr -> 'self_type
            method class_type : class_type -> 'self_type
            method class_sig_item : class_sig_item -> 'self_type
            method class_str_item : class_str_item -> 'self_type
            method with_constr : with_constr -> 'self_type
            method binding : binding -> 'self_type
            method module_binding : module_binding -> 'self_type
            method match_case : match_case -> 'self_type
            method ident : ident -> 'self_type
          end
        class c_expr : (expr -> expr) -> object inherit map end
        class c_patt : (patt -> patt) -> object inherit map end
        class c_ctyp : (ctyp -> ctyp) -> object inherit map end
        class c_str_item : (str_item -> str_item) -> object inherit map end
        class c_sig_item : (sig_item -> sig_item) -> object inherit map end
        class c_loc : (Loc.t -> Loc.t) -> object inherit map end
        val map_expr : (expr -> expr) -> expr -> expr
        val map_patt : (patt -> patt) -> patt -> patt
        val map_ctyp : (ctyp -> ctyp) -> ctyp -> ctyp
        val map_str_item : (str_item -> str_item) -> str_item -> str_item
        val map_sig_item : (sig_item -> sig_item) -> sig_item -> sig_item
        val map_loc : (Loc.t -> Loc.t) -> Loc.t -> Loc.t
        val ident_of_expr : expr -> ident
        val ident_of_ctyp : ctyp -> ident
        val biAnd_of_list : binding list -> binding
        val biSem_of_list : binding list -> binding
        val paSem_of_list : patt list -> patt
        val paCom_of_list : patt list -> patt
        val tyOr_of_list : ctyp list -> ctyp
        val tyAnd_of_list : ctyp list -> ctyp
        val tySem_of_list : ctyp list -> ctyp
        val stSem_of_list : str_item list -> str_item
        val sgSem_of_list : sig_item list -> sig_item
        val crSem_of_list : class_str_item list -> class_str_item
        val cgSem_of_list : class_sig_item list -> class_sig_item
        val ctAnd_of_list : class_type list -> class_type
        val ceAnd_of_list : class_expr list -> class_expr
        val wcAnd_of_list : with_constr list -> with_constr
        val meApp_of_list : module_expr list -> module_expr
        val mbAnd_of_list : module_binding list -> module_binding
        val mcOr_of_list : match_case list -> match_case
        val idAcc_of_list : ident list -> ident
        val idApp_of_list : ident list -> ident
        val exSem_of_list : expr list -> expr
        val exCom_of_list : expr list -> expr
        val list_of_ctyp : ctyp -> ctyp list -> ctyp list
        val list_of_binding : binding -> binding list -> binding list
        val list_of_with_constr :
          with_constr -> with_constr list -> with_constr list
        val list_of_patt : patt -> patt list -> patt list
        val list_of_expr : expr -> expr list -> expr list
        val list_of_str_item : str_item -> str_item list -> str_item list
        val list_of_sig_item : sig_item -> sig_item list -> sig_item list
        val list_of_class_sig_item :
          class_sig_item -> class_sig_item list -> class_sig_item list
        val list_of_class_str_item :
          class_str_item -> class_str_item list -> class_str_item list
        val list_of_class_type :
          class_type -> class_type list -> class_type list
        val list_of_class_expr :
          class_expr -> class_expr list -> class_expr list
        val list_of_module_expr :
          module_expr -> module_expr list -> module_expr list
        val list_of_module_binding :
          module_binding -> module_binding list -> module_binding list
        val list_of_match_case :
          match_case -> match_case list -> match_case list
        val list_of_ident : ident -> ident list -> ident list
        val safe_string_escaped : string -> string
        val is_irrefut_patt : patt -> bool
        val is_constructor : ident -> bool
        val is_patt_constructor : patt -> bool
        val is_expr_constructor : expr -> bool
        val ty_of_stl : (Loc.t * string * (ctyp list)) -> ctyp
        val ty_of_sbt : (Loc.t * string * bool * ctyp) -> ctyp
        val bi_of_pe : (patt * expr) -> binding
        val pel_of_binding : binding -> (patt * expr) list
        val binding_of_pel : (patt * expr) list -> binding
        val sum_type_of_list : (Loc.t * string * (ctyp list)) list -> ctyp
        val record_type_of_list : (Loc.t * string * bool * ctyp) list -> ctyp
      end
    module Camlp4AstToAst (M : Camlp4Ast) : Ast with module Loc = M.Loc
      and type meta_bool = M.meta_bool
      and type 'a meta_option = 'a M.meta_option and type ctyp = M.ctyp
      and type patt = M.patt and type expr = M.expr
      and type module_type = M.module_type and type sig_item = M.sig_item
      and type with_constr = M.with_constr
      and type module_expr = M.module_expr and type str_item = M.str_item
      and type class_type = M.class_type
      and type class_sig_item = M.class_sig_item
      and type class_expr = M.class_expr
      and type class_str_item = M.class_str_item and type binding = M.binding
      and type module_binding = M.module_binding
      and type match_case = M.match_case and type ident = M.ident = M
    module MakeCamlp4Ast (Loc : Type) =
      struct
        type meta_bool = | BTrue | BFalse | BAnt of string
        type 'a meta_option = | ONone | OSome of 'a | OAnt of string
        type ident =
          | IdAcc of Loc.t * ident * ident | IdApp of Loc.t * ident * ident
          | IdLid of Loc.t * string | IdUid of Loc.t * string
          | IdAnt of Loc.t * string
        type ctyp =
          | TyNil of Loc.t | TyAli of Loc.t * ctyp * ctyp | TyAny of Loc.t
          | TyApp of Loc.t * ctyp * ctyp | TyArr of Loc.t * ctyp * ctyp
          | TyCls of Loc.t * ident | TyLab of Loc.t * string * ctyp
          | TyId of Loc.t * ident | TyMan of Loc.t * ctyp * ctyp
          | TyDcl of Loc.t * string * ctyp list * ctyp * (ctyp * ctyp) list
          | TyObj of Loc.t * ctyp * meta_bool
          | TyOlb of Loc.t * string * ctyp | TyPol of Loc.t * ctyp * ctyp
          | TyQuo of Loc.t * string | TyQuP of Loc.t * string
          | TyQuM of Loc.t * string | TyVrn of Loc.t * string
          | TyRec of Loc.t * ctyp | TyCol of Loc.t * ctyp * ctyp
          | TySem of Loc.t * ctyp * ctyp | TyCom of Loc.t * ctyp * ctyp
          | TySum of Loc.t * ctyp | TyOf of Loc.t * ctyp * ctyp
          | TyAnd of Loc.t * ctyp * ctyp | TyOr of Loc.t * ctyp * ctyp
          | TyPrv of Loc.t * ctyp | TyMut of Loc.t * ctyp
          | TyTup of Loc.t * ctyp | TySta of Loc.t * ctyp * ctyp
          | TyVrnEq of Loc.t * ctyp | TyVrnSup of Loc.t * ctyp
          | TyVrnInf of Loc.t * ctyp | TyVrnInfSup of Loc.t * ctyp * ctyp
          | TyAmp of Loc.t * ctyp * ctyp | TyOfAmp of Loc.t * ctyp * ctyp
          | TyAnt of Loc.t * string
        type patt =
          | PaNil of Loc.t | PaId of Loc.t * ident
          | PaAli of Loc.t * patt * patt | PaAnt of Loc.t * string
          | PaAny of Loc.t | PaApp of Loc.t * patt * patt
          | PaArr of Loc.t * patt | PaCom of Loc.t * patt * patt
          | PaSem of Loc.t * patt * patt | PaChr of Loc.t * string
          | PaInt of Loc.t * string | PaInt32 of Loc.t * string
          | PaInt64 of Loc.t * string | PaNativeInt of Loc.t * string
          | PaFlo of Loc.t * string | PaLab of Loc.t * string * patt
          | PaOlb of Loc.t * string * patt
          | PaOlbi of Loc.t * string * patt * expr
          | PaOrp of Loc.t * patt * patt | PaRng of Loc.t * patt * patt
          | PaRec of Loc.t * patt | PaEq of Loc.t * patt * patt
          | PaStr of Loc.t * string | PaTup of Loc.t * patt
          | PaTyc of Loc.t * patt * ctyp | PaTyp of Loc.t * ident
          | PaVrn of Loc.t * string
          and expr =
          | ExNil of Loc.t | ExId of Loc.t * ident
          | ExAcc of Loc.t * expr * expr | ExAnt of Loc.t * string
          | ExApp of Loc.t * expr * expr | ExAre of Loc.t * expr * expr
          | ExArr of Loc.t * expr | ExSem of Loc.t * expr * expr
          | ExAsf of Loc.t | ExAsr of Loc.t * expr
          | ExAss of Loc.t * expr * expr | ExChr of Loc.t * string
          | ExCoe of Loc.t * expr * ctyp * ctyp | ExFlo of Loc.t * string
          | ExFor of Loc.t * string * expr * expr * meta_bool * expr
          | ExFun of Loc.t * match_case | ExIfe of Loc.t * expr * expr * expr
          | ExInt of Loc.t * string | ExInt32 of Loc.t * string
          | ExInt64 of Loc.t * string | ExNativeInt of Loc.t * string
          | ExLab of Loc.t * string * expr | ExLaz of Loc.t * expr
          | ExLet of Loc.t * meta_bool * binding * expr
          | ExLmd of Loc.t * string * module_expr * expr
          | ExMat of Loc.t * expr * match_case | ExNew of Loc.t * ident
          | ExObj of Loc.t * patt * class_str_item
          | ExOlb of Loc.t * string * expr | ExOvr of Loc.t * binding
          | ExRec of Loc.t * binding * expr | ExSeq of Loc.t * expr
          | ExSnd of Loc.t * expr * string | ExSte of Loc.t * expr * expr
          | ExStr of Loc.t * string | ExTry of Loc.t * expr * match_case
          | ExTup of Loc.t * expr | ExCom of Loc.t * expr * expr
          | ExTyc of Loc.t * expr * ctyp | ExVrn of Loc.t * string
          | ExWhi of Loc.t * expr * expr
          and module_type =
          | MtId of Loc.t * ident
          | MtFun of Loc.t * string * module_type * module_type
          | MtQuo of Loc.t * string | MtSig of Loc.t * sig_item
          | MtWit of Loc.t * module_type * with_constr
          | MtAnt of Loc.t * string
          and sig_item =
          | SgNil of Loc.t | SgCls of Loc.t * class_type
          | SgClt of Loc.t * class_type
          | SgSem of Loc.t * sig_item * sig_item
          | SgDir of Loc.t * string * expr | SgExc of Loc.t * ctyp
          | SgExt of Loc.t * string * ctyp * string
          | SgInc of Loc.t * module_type
          | SgMod of Loc.t * string * module_type
          | SgRecMod of Loc.t * module_binding
          | SgMty of Loc.t * string * module_type | SgOpn of Loc.t * ident
          | SgTyp of Loc.t * ctyp | SgVal of Loc.t * string * ctyp
          | SgAnt of Loc.t * string
          and with_constr =
          | WcNil of Loc.t | WcTyp of Loc.t * ctyp * ctyp
          | WcMod of Loc.t * ident * ident
          | WcAnd of Loc.t * with_constr * with_constr
          | WcAnt of Loc.t * string
          and binding =
          | BiNil of Loc.t | BiAnd of Loc.t * binding * binding
          | BiSem of Loc.t * binding * binding | BiEq of Loc.t * patt * expr
          | BiAnt of Loc.t * string
          and module_binding =
          | MbNil of Loc.t | MbAnd of Loc.t * module_binding * module_binding
          | MbColEq of Loc.t * string * module_type * module_expr
          | MbCol of Loc.t * string * module_type | MbAnt of Loc.t * string
          and match_case =
          | McNil of Loc.t | McOr of Loc.t * match_case * match_case
          | McArr of Loc.t * patt * expr * expr | McAnt of Loc.t * string
          and module_expr =
          | MeId of Loc.t * ident
          | MeApp of Loc.t * module_expr * module_expr
          | MeFun of Loc.t * string * module_type * module_expr
          | MeStr of Loc.t * str_item
          | MeTyc of Loc.t * module_expr * module_type
          | MeAnt of Loc.t * string
          and str_item =
          | StNil of Loc.t | StCls of Loc.t * class_expr
          | StClt of Loc.t * class_type
          | StSem of Loc.t * str_item * str_item
          | StDir of Loc.t * string * expr
          | StExc of Loc.t * ctyp * ident meta_option | StExp of Loc.t * expr
          | StExt of Loc.t * string * ctyp * string
          | StInc of Loc.t * module_expr
          | StMod of Loc.t * string * module_expr
          | StRecMod of Loc.t * module_binding
          | StMty of Loc.t * string * module_type | StOpn of Loc.t * ident
          | StTyp of Loc.t * ctyp | StVal of Loc.t * meta_bool * binding
          | StAnt of Loc.t * string
          and class_type =
          | CtNil of Loc.t | CtCon of Loc.t * meta_bool * ident * ctyp
          | CtFun of Loc.t * ctyp * class_type
          | CtSig of Loc.t * ctyp * class_sig_item
          | CtAnd of Loc.t * class_type * class_type
          | CtCol of Loc.t * class_type * class_type
          | CtEq of Loc.t * class_type * class_type | CtAnt of Loc.t * string
          and class_sig_item =
          | CgNil of Loc.t | CgCtr of Loc.t * ctyp * ctyp
          | CgSem of Loc.t * class_sig_item * class_sig_item
          | CgInh of Loc.t * class_type
          | CgMth of Loc.t * string * meta_bool * ctyp
          | CgVal of Loc.t * string * meta_bool * meta_bool * ctyp
          | CgVir of Loc.t * string * meta_bool * ctyp
          | CgAnt of Loc.t * string
          and class_expr =
          | CeNil of Loc.t | CeApp of Loc.t * class_expr * expr
          | CeCon of Loc.t * meta_bool * ident * ctyp
          | CeFun of Loc.t * patt * class_expr
          | CeLet of Loc.t * meta_bool * binding * class_expr
          | CeStr of Loc.t * patt * class_str_item
          | CeTyc of Loc.t * class_expr * class_type
          | CeAnd of Loc.t * class_expr * class_expr
          | CeEq of Loc.t * class_expr * class_expr | CeAnt of Loc.t * string
          and class_str_item =
          | CrNil of Loc.t | CrSem of Loc.t * class_str_item * class_str_item
          | CrCtr of Loc.t * ctyp * ctyp
          | CrInh of Loc.t * class_expr * string | CrIni of Loc.t * expr
          | CrMth of Loc.t * string * meta_bool * expr * ctyp
          | CrVal of Loc.t * string * meta_bool * expr
          | CrVir of Loc.t * string * meta_bool * ctyp
          | CrVvr of Loc.t * string * meta_bool * ctyp
          | CrAnt of Loc.t * string
      end
    module type AstFilters =
      sig
        module Ast : Camlp4Ast
        type 'a filter = 'a -> 'a
        val register_sig_item_filter : Ast.sig_item filter -> unit
        val register_str_item_filter : Ast.str_item filter -> unit
        val fold_interf_filters :
          ('a -> Ast.sig_item filter -> 'a) -> 'a -> 'a
        val fold_implem_filters :
          ('a -> Ast.str_item filter -> 'a) -> 'a -> 'a
      end
    type quotation =
      { q_name : string; q_loc : string; q_shift : int; q_contents : string
      }
    module type Quotation =
      sig
        module Ast : Ast
        open Ast
        type 'a expand_fun = Loc.t -> string option -> string -> 'a
        type expander =
          | ExStr of (bool -> string expand_fun)
          | ExAst of Ast.expr expand_fun * Ast.patt expand_fun
        val add : string -> expander -> unit
        val find : string -> expander
        val default : string ref
        val translate : (string -> string) ref
        val expand_expr :
          (Loc.t -> string -> Ast.expr) -> Loc.t -> quotation -> Ast.expr
        val expand_patt :
          (Loc.t -> string -> Ast.patt) -> Loc.t -> quotation -> Ast.patt
        val dump_file : (string option) ref
        module Error : Error
      end
    type ('a, 'loc) stream_filter =
      ('a * 'loc) Stream.t -> ('a * 'loc) Stream.t
    module type Token =
      sig
        module Loc : Loc
        type t
        val to_string : t -> string
        val print : Format.formatter -> t -> unit
        val match_keyword : string -> t -> bool
        val extract_string : t -> string
        module Filter :
          sig
            type token_filter = (t, Loc.t) stream_filter
            type t
            val mk : (string -> bool) -> t
            val define_filter : t -> (token_filter -> token_filter) -> unit
            val filter : t -> token_filter
            val keyword_added : t -> string -> bool -> unit
            val keyword_removed : t -> string -> unit
          end
        module Error : Error
      end
    type camlp4_token =
      | KEYWORD of string | SYMBOL of string | LIDENT of string
      | UIDENT of string | ESCAPED_IDENT of string | INT of int * string
      | INT32 of int32 * string | INT64 of int64 * string
      | NATIVEINT of nativeint * string | FLOAT of float * string
      | CHAR of char * string | STRING of string * string | LABEL of string
      | OPTLABEL of string | QUOTATION of quotation
      | ANTIQUOT of string * string | COMMENT of string | BLANKS of string
      | NEWLINE | LINE_DIRECTIVE of int * string option | EOI
    module type Camlp4Token = Token with type t = camlp4_token
    module type DynLoader =
      sig
        type t
        exception Error of string * string
        val mk : ?ocaml_stdlib: bool -> ?camlp4_stdlib: bool -> unit -> t
        val fold_load_path : t -> (string -> 'a -> 'a) -> 'a -> 'a
        val load : t -> string -> unit
        val include_dir : t -> string -> unit
        val find_in_path : t -> string -> string
      end
    module Grammar =
      struct
        module type Action =
          sig
            type t
            val mk : 'a -> t
            val get : t -> 'a
            val getf : t -> 'a -> 'b
            val getf2 : t -> 'a -> 'b -> 'c
          end
        type assoc = | NonA | RightA | LeftA
        type position =
          | First | Last | Before of string | After of string
          | Level of string
        module type Structure =
          sig
            module Loc : Loc
            module Action : Action
            module Token : Token with module Loc = Loc
            type gram
            type internal_entry
            type tree
            type token_pattern = ((Token.t -> bool) * string)
            type symbol =
              | Smeta of string * symbol list * Action.t
              | Snterm of internal_entry | Snterml of internal_entry * string
              | Slist0 of symbol | Slist0sep of symbol * symbol
              | Slist1 of symbol | Slist1sep of symbol * symbol
              | Sopt of symbol | Sself | Snext | Stoken of token_pattern
              | Skeyword of string | Stree of tree
            type production_rule = ((symbol list) * Action.t)
            type single_extend_statment =
              ((string option) * (assoc option) * (production_rule list))
            type extend_statment =
              ((position option) * (single_extend_statment list))
            type delete_statment = symbol list
            type ('a, 'b, 'c) fold =
              internal_entry ->
                symbol list -> ('a Stream.t -> 'b) -> 'a Stream.t -> 'c
            type ('a, 'b, 'c) foldsep =
              internal_entry ->
                symbol list ->
                  ('a Stream.t -> 'b) ->
                    ('a Stream.t -> unit) -> 'a Stream.t -> 'c
          end
        module type Dynamic =
          sig
            include Structure
            val mk : unit -> gram
            module Entry :
              sig
                type 'a t
                val mk : gram -> string -> 'a t
                val of_parser :
                  gram ->
                    string -> ((Token.t * Loc.t) Stream.t -> 'a) -> 'a t
                val setup_parser :
                  'a t -> ((Token.t * Loc.t) Stream.t -> 'a) -> unit
                val name : 'a t -> string
                val print : Format.formatter -> 'a t -> unit
                val dump : Format.formatter -> 'a t -> unit
                val obj : 'a t -> internal_entry
                val clear : 'a t -> unit
              end
            val get_filter : gram -> Token.Filter.t
            type 'a not_filtered
            val extend : 'a Entry.t -> extend_statment -> unit
            val delete_rule : 'a Entry.t -> delete_statment -> unit
            val srules :
              'a Entry.t -> ((symbol list) * Action.t) list -> symbol
            val sfold0 : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) fold
            val sfold1 : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) fold
            val sfold0sep : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) foldsep
            val lex :
              gram ->
                Loc.t ->
                  char Stream.t -> ((Token.t * Loc.t) Stream.t) not_filtered
            val lex_string :
              gram ->
                Loc.t -> string -> ((Token.t * Loc.t) Stream.t) not_filtered
            val filter :
              gram ->
                ((Token.t * Loc.t) Stream.t) not_filtered ->
                  (Token.t * Loc.t) Stream.t
            val parse : 'a Entry.t -> Loc.t -> char Stream.t -> 'a
            val parse_string : 'a Entry.t -> Loc.t -> string -> 'a
            val parse_tokens_before_filter :
              'a Entry.t -> ((Token.t * Loc.t) Stream.t) not_filtered -> 'a
            val parse_tokens_after_filter :
              'a Entry.t -> (Token.t * Loc.t) Stream.t -> 'a
          end
        module type Static =
          sig
            include Structure
            module Entry :
              sig
                type 'a t
                val mk : string -> 'a t
                val of_parser :
                  string -> ((Token.t * Loc.t) Stream.t -> 'a) -> 'a t
                val setup_parser :
                  'a t -> ((Token.t * Loc.t) Stream.t -> 'a) -> unit
                val name : 'a t -> string
                val print : Format.formatter -> 'a t -> unit
                val dump : Format.formatter -> 'a t -> unit
                val obj : 'a t -> internal_entry
                val clear : 'a t -> unit
              end
            val get_filter : unit -> Token.Filter.t
            type 'a not_filtered
            val extend : 'a Entry.t -> extend_statment -> unit
            val delete_rule : 'a Entry.t -> delete_statment -> unit
            val srules :
              'a Entry.t -> ((symbol list) * Action.t) list -> symbol
            val sfold0 : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) fold
            val sfold1 : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) fold
            val sfold0sep : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) foldsep
            val lex :
              Loc.t ->
                char Stream.t -> ((Token.t * Loc.t) Stream.t) not_filtered
            val lex_string :
              Loc.t -> string -> ((Token.t * Loc.t) Stream.t) not_filtered
            val filter :
              ((Token.t * Loc.t) Stream.t) not_filtered ->
                (Token.t * Loc.t) Stream.t
            val parse : 'a Entry.t -> Loc.t -> char Stream.t -> 'a
            val parse_string : 'a Entry.t -> Loc.t -> string -> 'a
            val parse_tokens_before_filter :
              'a Entry.t -> ((Token.t * Loc.t) Stream.t) not_filtered -> 'a
            val parse_tokens_after_filter :
              'a Entry.t -> (Token.t * Loc.t) Stream.t -> 'a
          end
      end
    module type Lexer =
      sig
        module Loc : Loc
        module Token : Token with module Loc = Loc
        module Error : Error
        val mk : unit -> Loc.t -> char Stream.t -> (Token.t * Loc.t) Stream.t
      end
    module type Parser =
      sig
        module Ast : Ast
        open Ast
        val parse_implem :
          ?directive_handler: (str_item -> str_item option) ->
            Loc.t -> char Stream.t -> Ast.str_item
        val parse_interf :
          ?directive_handler: (sig_item -> sig_item option) ->
            Loc.t -> char Stream.t -> Ast.sig_item
      end
    module type Printer =
      sig
        module Ast : Ast
        val print_interf :
          ?input_file: string -> ?output_file: string -> Ast.sig_item -> unit
        val print_implem :
          ?input_file: string -> ?output_file: string -> Ast.str_item -> unit
      end
    module type Syntax =
      sig
        module Loc : Loc
        module Warning : Warning with module Loc = Loc
        module Ast : Ast with module Loc = Loc
        module Token : Token with module Loc = Loc
        module Gram : Grammar.Static with module Loc = Loc
          and module Token = Token
        module AntiquotSyntax : AntiquotSyntax with module Ast = Ast
        module Quotation : Quotation with module Ast = Ast
        module Parser : Parser with module Ast = Ast
        module Printer : Printer with module Ast = Ast
      end
    module type Camlp4Syntax =
      sig
        module Loc : Loc
        module Warning : Warning with module Loc = Loc
        module Ast : Camlp4Ast with module Loc = Loc
        module Token : Camlp4Token with module Loc = Loc
        module Gram : Grammar.Static with module Loc = Loc
          and module Token = Token
        module AntiquotSyntax :
          AntiquotSyntax with module Ast = Camlp4AstToAst(Ast)
        module Quotation : Quotation with module Ast = Camlp4AstToAst(Ast)
        module Parser : Parser with module Ast = Camlp4AstToAst(Ast)
        module Printer : Printer with module Ast = Camlp4AstToAst(Ast)
        val interf : ((Ast.sig_item list) * (Loc.t option)) Gram.Entry.t
        val implem : ((Ast.str_item list) * (Loc.t option)) Gram.Entry.t
        val top_phrase : (Ast.str_item option) Gram.Entry.t
        val use_file : ((Ast.str_item list) * (Loc.t option)) Gram.Entry.t
        val a_CHAR : string Gram.Entry.t
        val a_FLOAT : string Gram.Entry.t
        val a_INT : string Gram.Entry.t
        val a_INT32 : string Gram.Entry.t
        val a_INT64 : string Gram.Entry.t
        val a_LABEL : string Gram.Entry.t
        val a_LIDENT : string Gram.Entry.t
        val a_LIDENT_or_operator : string Gram.Entry.t
        val a_NATIVEINT : string Gram.Entry.t
        val a_OPTLABEL : string Gram.Entry.t
        val a_STRING : string Gram.Entry.t
        val a_UIDENT : string Gram.Entry.t
        val a_ident : string Gram.Entry.t
        val amp_ctyp : Ast.ctyp Gram.Entry.t
        val and_ctyp : Ast.ctyp Gram.Entry.t
        val match_case : Ast.match_case Gram.Entry.t
        val match_case0 : Ast.match_case Gram.Entry.t
        val match_case_quot : Ast.match_case Gram.Entry.t
        val binding : Ast.binding Gram.Entry.t
        val binding_quot : Ast.binding Gram.Entry.t
        val class_declaration : Ast.class_expr Gram.Entry.t
        val class_description : Ast.class_type Gram.Entry.t
        val class_expr : Ast.class_expr Gram.Entry.t
        val class_expr_quot : Ast.class_expr Gram.Entry.t
        val class_fun_binding : Ast.class_expr Gram.Entry.t
        val class_fun_def : Ast.class_expr Gram.Entry.t
        val class_info_for_class_expr : Ast.class_expr Gram.Entry.t
        val class_info_for_class_type : Ast.class_type Gram.Entry.t
        val class_longident : Ast.ident Gram.Entry.t
        val class_longident_and_param : Ast.class_expr Gram.Entry.t
        val class_name_and_param : (string * Ast.ctyp) Gram.Entry.t
        val class_sig_item : Ast.class_sig_item Gram.Entry.t
        val class_sig_item_quot : Ast.class_sig_item Gram.Entry.t
        val class_signature : Ast.class_sig_item Gram.Entry.t
        val class_str_item : Ast.class_str_item Gram.Entry.t
        val class_str_item_quot : Ast.class_str_item Gram.Entry.t
        val class_structure : Ast.class_str_item Gram.Entry.t
        val class_type : Ast.class_type Gram.Entry.t
        val class_type_declaration : Ast.class_type Gram.Entry.t
        val class_type_longident : Ast.ident Gram.Entry.t
        val class_type_longident_and_param : Ast.class_type Gram.Entry.t
        val class_type_plus : Ast.class_type Gram.Entry.t
        val class_type_quot : Ast.class_type Gram.Entry.t
        val comma_ctyp : Ast.ctyp Gram.Entry.t
        val comma_expr : Ast.expr Gram.Entry.t
        val comma_ipatt : Ast.patt Gram.Entry.t
        val comma_patt : Ast.patt Gram.Entry.t
        val comma_type_parameter : Ast.ctyp Gram.Entry.t
        val constrain : (Ast.ctyp * Ast.ctyp) Gram.Entry.t
        val constructor_arg_list : Ast.ctyp Gram.Entry.t
        val constructor_declaration : Ast.ctyp Gram.Entry.t
        val constructor_declarations : Ast.ctyp Gram.Entry.t
        val ctyp : Ast.ctyp Gram.Entry.t
        val ctyp_quot : Ast.ctyp Gram.Entry.t
        val cvalue_binding : Ast.expr Gram.Entry.t
        val direction_flag : Ast.meta_bool Gram.Entry.t
        val dummy : unit Gram.Entry.t
        val eq_expr : (string -> Ast.patt -> Ast.patt) Gram.Entry.t
        val expr : Ast.expr Gram.Entry.t
        val expr_eoi : Ast.expr Gram.Entry.t
        val expr_quot : Ast.expr Gram.Entry.t
        val field : Ast.ctyp Gram.Entry.t
        val field_expr : Ast.binding Gram.Entry.t
        val fun_binding : Ast.expr Gram.Entry.t
        val fun_def : Ast.expr Gram.Entry.t
        val ident : Ast.ident Gram.Entry.t
        val ident_quot : Ast.ident Gram.Entry.t
        val ipatt : Ast.patt Gram.Entry.t
        val ipatt_tcon : Ast.patt Gram.Entry.t
        val label : string Gram.Entry.t
        val label_declaration : Ast.ctyp Gram.Entry.t
        val label_expr : Ast.binding Gram.Entry.t
        val label_ipatt : Ast.patt Gram.Entry.t
        val label_longident : Ast.ident Gram.Entry.t
        val label_patt : Ast.patt Gram.Entry.t
        val labeled_ipatt : Ast.patt Gram.Entry.t
        val let_binding : Ast.binding Gram.Entry.t
        val meth_list : Ast.ctyp Gram.Entry.t
        val module_binding : Ast.module_binding Gram.Entry.t
        val module_binding0 : Ast.module_expr Gram.Entry.t
        val module_binding_quot : Ast.module_binding Gram.Entry.t
        val module_declaration : Ast.module_type Gram.Entry.t
        val module_expr : Ast.module_expr Gram.Entry.t
        val module_expr_quot : Ast.module_expr Gram.Entry.t
        val module_longident : Ast.ident Gram.Entry.t
        val module_longident_with_app : Ast.ident Gram.Entry.t
        val module_rec_declaration : Ast.module_binding Gram.Entry.t
        val module_type : Ast.module_type Gram.Entry.t
        val module_type_quot : Ast.module_type Gram.Entry.t
        val more_ctyp : Ast.ctyp Gram.Entry.t
        val name_tags : Ast.ctyp Gram.Entry.t
        val opt_as_lident : string Gram.Entry.t
        val opt_class_self_patt : Ast.patt Gram.Entry.t
        val opt_class_self_type : Ast.ctyp Gram.Entry.t
        val opt_comma_ctyp : Ast.ctyp Gram.Entry.t
        val opt_dot_dot : Ast.meta_bool Gram.Entry.t
        val opt_eq_ctyp : (Ast.ctyp list -> Ast.ctyp) Gram.Entry.t
        val opt_expr : Ast.expr Gram.Entry.t
        val opt_meth_list : Ast.ctyp Gram.Entry.t
        val opt_mutable : Ast.meta_bool Gram.Entry.t
        val opt_polyt : Ast.ctyp Gram.Entry.t
        val opt_private : Ast.meta_bool Gram.Entry.t
        val opt_rec : Ast.meta_bool Gram.Entry.t
        val opt_virtual : Ast.meta_bool Gram.Entry.t
        val opt_when_expr : Ast.expr Gram.Entry.t
        val patt : Ast.patt Gram.Entry.t
        val patt_as_patt_opt : Ast.patt Gram.Entry.t
        val patt_eoi : Ast.patt Gram.Entry.t
        val patt_quot : Ast.patt Gram.Entry.t
        val patt_tcon : Ast.patt Gram.Entry.t
        val phrase : Ast.str_item Gram.Entry.t
        val pipe_ctyp : Ast.ctyp Gram.Entry.t
        val poly_type : Ast.ctyp Gram.Entry.t
        val row_field : Ast.ctyp Gram.Entry.t
        val sem_ctyp : Ast.ctyp Gram.Entry.t
        val sem_expr : Ast.expr Gram.Entry.t
        val sem_expr_for_list : (Ast.expr -> Ast.expr) Gram.Entry.t
        val sem_patt : Ast.patt Gram.Entry.t
        val sem_patt_for_list : (Ast.patt -> Ast.patt) Gram.Entry.t
        val semi : unit Gram.Entry.t
        val sequence : Ast.expr Gram.Entry.t
        val sig_item : Ast.sig_item Gram.Entry.t
        val sig_item_quot : Ast.sig_item Gram.Entry.t
        val sig_items : Ast.sig_item Gram.Entry.t
        val star_ctyp : Ast.ctyp Gram.Entry.t
        val str_item : Ast.str_item Gram.Entry.t
        val str_item_quot : Ast.str_item Gram.Entry.t
        val str_items : Ast.str_item Gram.Entry.t
        val type_constraint : unit Gram.Entry.t
        val type_declaration : Ast.ctyp Gram.Entry.t
        val type_ident_and_parameters :
          (string * (Ast.ctyp list)) Gram.Entry.t
        val type_kind : Ast.ctyp Gram.Entry.t
        val type_longident : Ast.ident Gram.Entry.t
        val type_longident_and_parameters : Ast.ctyp Gram.Entry.t
        val type_parameter : Ast.ctyp Gram.Entry.t
        val type_parameters : (Ast.ctyp -> Ast.ctyp) Gram.Entry.t
        val typevars : Ast.ctyp Gram.Entry.t
        val val_longident : Ast.ident Gram.Entry.t
        val value_let : unit Gram.Entry.t
        val value_val : unit Gram.Entry.t
        val with_constr : Ast.with_constr Gram.Entry.t
        val with_constr_quot : Ast.with_constr Gram.Entry.t
      end
    module type SyntaxExtension =
      functor (Syn : Syntax) -> Syntax with module Loc = Syn.Loc
        and module Warning = Syn.Warning and module Ast = Syn.Ast
        and module Token = Syn.Token and module Gram = Syn.Gram
        and module AntiquotSyntax = Syn.AntiquotSyntax
        and module Quotation = Syn.Quotation
  end
module ErrorHandler :
  sig
    val print : Format.formatter -> exn -> unit
    val try_print : Format.formatter -> exn -> unit
    val to_string : exn -> string
    val try_to_string : exn -> string
    val register : (Format.formatter -> exn -> unit) -> unit
    module Register (Error : Sig.Error) : sig  end
    module ObjTools :
      sig
        val print : Format.formatter -> Obj.t -> unit
        val print_desc : Format.formatter -> Obj.t -> unit
        val to_string : Obj.t -> string
        val desc : Obj.t -> string
      end
  end =
  struct
    open Format
    module ObjTools =
      struct
        let desc obj =
          if Obj.is_block obj
          then "tag = " ^ (string_of_int (Obj.tag obj))
          else "int_val = " ^ (string_of_int (Obj.obj obj))
        let rec to_string r =
          if Obj.is_int r
          then
            (let i : int = Obj.magic r
             in (string_of_int i) ^ (" | CstTag" ^ (string_of_int (i + 1))))
          else
            (let rec get_fields acc =
               function
               | 0 -> acc
               | n -> let n = n - 1 in get_fields ((Obj.field r n) :: acc) n in
             let rec is_list r =
               if Obj.is_int r
               then r = (Obj.repr 0)
               else
                 (let s = Obj.size r
                  and t = Obj.tag r
                  in (t = 0) && ((s = 2) && (is_list (Obj.field r 1)))) in
             let rec get_list r =
               if Obj.is_int r
               then []
               else
                 (let h = Obj.field r 0
                  and t = get_list (Obj.field r 1)
                  in h :: t) in
             let opaque name = "<" ^ (name ^ ">") in
             let s = Obj.size r
             and t = Obj.tag r
             in
               match t with
               | _ when is_list r ->
                   let fields = get_list r
                   in
                     "[" ^
                       ((String.concat "; " (List.map to_string fields)) ^
                          "]")
               | 0 ->
                   let fields = get_fields [] s
                   in
                     "(" ^
                       ((String.concat ", " (List.map to_string fields)) ^
                          ")")
               | x when x = Obj.lazy_tag -> opaque "lazy"
               | x when x = Obj.closure_tag -> opaque "closure"
               | x when x = Obj.object_tag ->
                   let fields = get_fields [] s in
                   let (_class, id, slots) =
                     (match fields with
                      | h :: h' :: t -> (h, h', t)
                      | _ -> assert false)
                   in
                     "Object #" ^
                       ((to_string id) ^
                          (" (" ^
                             ((String.concat ", " (List.map to_string slots))
                                ^ ")")))
               | x when x = Obj.infix_tag -> opaque "infix"
               | x when x = Obj.forward_tag -> opaque "forward"
               | x when x < Obj.no_scan_tag ->
                   let fields = get_fields [] s
                   in
                     "Tag" ^
                       ((string_of_int t) ^
                          (" (" ^
                             ((String.concat ", " (List.map to_string fields))
                                ^ ")")))
               | x when x = Obj.string_tag ->
                   "\"" ^ ((String.escaped (Obj.magic r : string)) ^ "\"")
               | x when x = Obj.double_tag ->
                   string_of_float (Obj.magic r : float)
               | x when x = Obj.abstract_tag -> opaque "abstract"
               | x when x = Obj.custom_tag -> opaque "custom"
               | x when x = Obj.final_tag -> opaque "final"
               | _ ->
                   failwith
                     ("ObjTools.to_string: unknown tag (" ^
                        ((string_of_int t) ^ ")")))
        let print ppf x = fprintf ppf "%s" (to_string x)
        let print_desc ppf x = fprintf ppf "%s" (desc x)
      end
    let default_handler ppf x =
      let x = Obj.repr x
      in
        (fprintf ppf "Camlp4: Uncaught exception: %s"
           (Obj.obj (Obj.field (Obj.field x 0) 0) : string);
         if (Obj.size x) > 1
         then
           (pp_print_string ppf " (";
            for i = 1 to (Obj.size x) - 1 do
              if i > 1 then pp_print_string ppf ", " else ();
              ObjTools.print ppf (Obj.field x i)
            done;
            pp_print_char ppf ')')
         else ();
         fprintf ppf "@.")
    let handler =
      ref (fun ppf default_handler exn -> default_handler ppf exn)
    let register f =
      let current_handler = !handler
      in
        handler :=
          fun ppf default_handler exn ->
            try f ppf exn
            with | exn -> current_handler ppf default_handler exn
    module Register (Error : Sig.Error) =
      struct
        let _ =
          let current_handler = !handler
          in
            handler :=
              fun ppf default_handler ->
                function
                | Error.E x -> Error.print ppf x
                | x -> current_handler ppf default_handler x
      end
    let gen_print ppf default_handler =
      function
      | Out_of_memory -> fprintf ppf "Out of memory"
      | Assert_failure ((file, line, char)) ->
          fprintf ppf "Assertion failed, file %S, line %d, char %d" file line
            char
      | Match_failure ((file, line, char)) ->
          fprintf ppf "Pattern matching failed, file %S, line %d, char %d"
            file line char
      | Failure str -> fprintf ppf "Failure: %S" str
      | Invalid_argument str -> fprintf ppf "Invalid argument: %S" str
      | Sys_error str -> fprintf ppf "I/O error: %S" str
      | Stream.Failure -> fprintf ppf "Parse failure"
      | Stream.Error str -> fprintf ppf "Parse error: %s" str
      | x -> !handler ppf default_handler x
    let print ppf = gen_print ppf default_handler
    let try_print ppf = gen_print ppf (fun _ -> raise)
    let to_string exn =
      let buf = Buffer.create 128 in
      let () = bprintf buf "%a" print exn in Buffer.contents buf
    let try_to_string exn =
      let buf = Buffer.create 128 in
      let () = bprintf buf "%a" try_print exn in Buffer.contents buf
  end
module Struct =
  struct
    module Loc : sig include Sig.Loc end =
      struct
        open Format
        type pos = { line : int; bol : int; off : int }
        type t =
          { file_name : string; start : pos; stop : pos; ghost : bool
          }
        let dump_sel f x =
          let s =
            match x with
            | `start -> "`start"
            | `stop -> "`stop"
            | `both -> "`both"
            | _ -> "<not-printable>"
          in pp_print_string f s
        let dump_pos f x =
          fprintf f "@[<hov 2>{ line = %d ;@ bol = %d ;@ off = %d } : pos@]"
            x.line x.bol x.off
        let dump_long f x =
          fprintf f
            "@[<hov 2>{ file_name = %s ;@ start = %a (%d-%d);@ stop = %a (%d);@ ghost = %b@ } : Loc.t@]"
            x.file_name dump_pos x.start (x.start.off - x.start.bol)
            (x.stop.off - x.start.bol) dump_pos x.stop
            (x.stop.off - x.stop.bol) x.ghost
        let dump f x =
          fprintf f "[%S: %d:%d-%d %d:%d%t]" x.file_name x.start.line
            (x.start.off - x.start.bol) (x.stop.off - x.start.bol)
            x.stop.line (x.stop.off - x.stop.bol)
            (fun o -> if x.ghost then fprintf o " (ghost)" else ())
        let start_pos = {  line = 1; bol = 0; off = 0; }
        let ghost =
          {
            
            file_name = "ghost-location";
            start = start_pos;
            stop = start_pos;
            ghost = true;
          }
        let mk file_name =
          {
            
            file_name = file_name;
            start = start_pos;
            stop = start_pos;
            ghost = false;
          }
        let of_tuple (file_name, start_line, start_bol, start_off, stop_line,
                      stop_bol, stop_off, ghost)
                     =
          {
            
            file_name = file_name;
            start = {  line = start_line; bol = start_bol; off = start_off; };
            stop = {  line = stop_line; bol = stop_bol; off = stop_off; };
            ghost = ghost;
          }
        let to_tuple {
                       file_name = file_name;
                       start =
                         {
                           line = start_line;
                           bol = start_bol;
                           off = start_off
                         };
                       stop =
                         { line = stop_line; bol = stop_bol; off = stop_off };
                       ghost = ghost
                     } =
          (file_name, start_line, start_bol, start_off, stop_line, stop_bol,
           stop_off, ghost)
        let pos_of_lexing_position p =
          let pos =
            {
              
              line = p.Lexing.pos_lnum;
              bol = p.Lexing.pos_bol;
              off = p.Lexing.pos_cnum;
            }
          in pos
        let pos_to_lexing_position p file_name =
          {
            
            Lexing.pos_fname = file_name;
            pos_lnum = p.line;
            pos_bol = p.bol;
            pos_cnum = p.off;
          }
        let better_file_name a b =
          match (a, b) with
          | ("", "") -> a
          | ("", x) -> x
          | (x, "") -> x
          | ("-", x) -> x
          | (x, "-") -> x
          | (x, _) -> x
        let of_lexbuf lb =
          let start = Lexing.lexeme_start_p lb
          and stop = Lexing.lexeme_end_p lb in
          let loc =
            {
              
              file_name =
                better_file_name start.Lexing.pos_fname stop.Lexing.pos_fname;
              start = pos_of_lexing_position start;
              stop = pos_of_lexing_position stop;
              ghost = false;
            }
          in loc
        let of_lexing_position pos =
          let loc =
            {
              
              file_name = pos.Lexing.pos_fname;
              start = pos_of_lexing_position pos;
              stop = pos_of_lexing_position pos;
              ghost = false;
            }
          in loc
        let to_ocaml_location x =
          {
            
            Location.loc_start = pos_to_lexing_position x.start x.file_name;
            loc_end = pos_to_lexing_position x.stop x.file_name;
            loc_ghost = x.ghost;
          }
        let of_ocaml_location x =
          let (a, b) = ((x.Location.loc_start), (x.Location.loc_end)) in
          let res =
            {
              
              file_name =
                better_file_name a.Lexing.pos_fname b.Lexing.pos_fname;
              start = pos_of_lexing_position a;
              stop = pos_of_lexing_position b;
              ghost = x.Location.loc_ghost;
            }
          in res
        let start_pos x = pos_to_lexing_position x.start x.file_name
        let stop_pos x = pos_to_lexing_position x.stop x.file_name
        let merge a b =
          if a == b
          then a
          else
            (let r =
               match ((a.ghost), (b.ghost)) with
               | (false, false) -> { (a) with  stop = b.stop; }
               | (true, true) -> { (a) with  stop = b.stop; }
               | (true, _) -> { (a) with  stop = b.stop; }
               | (_, true) -> { (b) with  start = a.start; }
             in r)
        let join x = { (x) with  stop = x.start; }
        let map f start_stop_both x =
          match start_stop_both with
          | `start -> { (x) with  start = f x.start; }
          | `stop -> { (x) with  stop = f x.stop; }
          | `both -> { (x) with  start = f x.start; stop = f x.stop; }
        let move_pos chars x = { (x) with  off = x.off + chars; }
        let move s chars x = map (move_pos chars) s x
        let move_line lines x =
          let move_line_pos x =
            { (x) with  line = x.line + lines; bol = x.off; }
          in map move_line_pos `both x
        let shift width x =
          { (x) with  start = x.stop; stop = move_pos width x.stop; }
        let file_name x = x.file_name
        let start_line x = x.start.line
        let stop_line x = x.stop.line
        let start_bol x = x.start.bol
        let stop_bol x = x.stop.bol
        let start_off x = x.start.off
        let stop_off x = x.stop.off
        let is_ghost x = x.ghost
        let set_file_name s x = { (x) with  file_name = s; }
        let ghostify x = { (x) with  ghost = true; }
        let make_absolute x =
          let pwd = Sys.getcwd ()
          in
            if Filename.is_relative x.file_name
            then { (x) with  file_name = Filename.concat pwd x.file_name; }
            else x
        let strictly_before x y =
          let b = (x.stop.off < y.start.off) && (x.file_name = y.file_name)
          in b
        let to_string x =
          let (a, b) = ((x.start), (x.stop)) in
          let res =
            sprintf "File \"%s\", line %d, characters %d-%d" x.file_name
              a.line (a.off - a.bol) (b.off - a.bol)
          in
            if x.start.line <> x.stop.line
            then
              sprintf "%s (end at line %d, character %d)" res x.stop.line
                (b.off - b.bol)
            else res
        let print out x = pp_print_string out (to_string x)
        let check x msg =
          if
            ((start_line x) > (stop_line x)) ||
              (((start_bol x) > (stop_bol x)) ||
                 (((start_off x) > (stop_off x)) ||
                    (((start_line x) < 0) ||
                       (((stop_line x) < 0) ||
                          (((start_bol x) < 0) ||
                             (((stop_bol x) < 0) ||
                                (((start_off x) < 0) || ((stop_off x) < 0))))))))
          then
            (eprintf "*** Warning: (%s) strange positions ***\n%a@\n" msg
               print x;
             false)
          else true
        exception Exc_located of t * exn
        let _ =
          ErrorHandler.register
            (fun ppf ->
               function
               | Exc_located (loc, exn) ->
                   fprintf ppf "%a:@\n%a" print loc ErrorHandler.print exn
               | exn -> raise exn)
        let name = ref "_loc"
        let raise loc exc =
          match exc with
          | Exc_located (_, _) -> raise exc
          | _ -> raise (Exc_located (loc, exc))
      end
    module Warning =
      struct
        module Make (Loc : Sig.Loc) : Sig.Warning with module Loc = Loc =
          struct
            module Loc = Loc
            open Format
            type t = Loc.t -> string -> unit
            let default loc txt = eprintf "<W> %a: %s@." Loc.print loc txt
            let current = ref default
            let print loc txt = !current loc txt
          end
      end
    module Token :
      sig
        module Make (Loc : Sig.Loc) : Sig.Camlp4Token with module Loc = Loc
        module Eval :
          sig
            val char : string -> char
            val string : ?strict: unit -> string -> string
          end
      end =
      struct
        open Format
        module Make (Loc : Sig.Loc) : Sig.Camlp4Token with module Loc = Loc =
          struct
            module Loc = Loc
            open Sig
            type t = camlp4_token
            type token = t
            let to_string =
              function
              | KEYWORD s -> sprintf "KEYWORD %S" s
              | SYMBOL s -> sprintf "SYMBOL %S" s
              | LIDENT s -> sprintf "LIDENT %S" s
              | UIDENT s -> sprintf "UIDENT %S" s
              | INT (_, s) -> sprintf "INT %s" s
              | INT32 (_, s) -> sprintf "INT32 %sd" s
              | INT64 (_, s) -> sprintf "INT64 %sd" s
              | NATIVEINT (_, s) -> sprintf "NATIVEINT %sd" s
              | FLOAT (_, s) -> sprintf "FLOAT %s" s
              | CHAR (_, s) -> sprintf "CHAR '%s'" s
              | STRING (_, s) -> sprintf "STRING \"%s\"" s
              | LABEL s -> sprintf "LABEL %S" s
              | OPTLABEL s -> sprintf "OPTLABEL %S" s
              | ANTIQUOT (n, s) -> sprintf "ANTIQUOT %s: %S" n s
              | QUOTATION x ->
                  sprintf
                    "QUOTATION { q_name=%S; q_loc=%S; q_shift=%d; q_contents=%S }"
                    x.q_name x.q_loc x.q_shift x.q_contents
              | COMMENT s -> sprintf "COMMENT %S" s
              | BLANKS s -> sprintf "BLANKS %S" s
              | NEWLINE -> sprintf "NEWLINE"
              | EOI -> sprintf "EOI"
              | ESCAPED_IDENT s -> sprintf "ESCAPED_IDENT %S" s
              | LINE_DIRECTIVE (i, None) -> sprintf "LINE_DIRECTIVE %d" i
              | LINE_DIRECTIVE (i, (Some s)) ->
                  sprintf "LINE_DIRECTIVE %d %S" i s
            let print ppf x = pp_print_string ppf (to_string x)
            let match_keyword kwd =
              function | KEYWORD kwd' when kwd = kwd' -> true | _ -> false
            let extract_string =
              function
              | KEYWORD s | SYMBOL s | LIDENT s | UIDENT s | INT (_, s) |
                  INT32 (_, s) | INT64 (_, s) | NATIVEINT (_, s) |
                  FLOAT (_, s) | CHAR (_, s) | STRING (_, s) | LABEL s |
                  OPTLABEL s | COMMENT s | BLANKS s | ESCAPED_IDENT s -> s
              | tok ->
                  invalid_arg
                    ("Cannot extract a string from a this token: " ^
                       (to_string tok))
            module Error =
              struct
                type t =
                  | Illegal_token of string | Keyword_as_label of string
                  | Illegal_token_pattern of string * string
                  | Illegal_constructor of string
                exception E of t
                let print ppf =
                  function
                  | Illegal_token s -> fprintf ppf "Illegal token (%s)" s
                  | Keyword_as_label kwd ->
                      fprintf ppf
                        "`%s' is a keyword, it cannot be used as label name"
                        kwd
                  | Illegal_token_pattern (p_con, p_prm) ->
                      fprintf ppf "Illegal token pattern: %s %S" p_con p_prm
                  | Illegal_constructor con ->
                      fprintf ppf "Illegal constructor %S" con
                let to_string x =
                  let b = Buffer.create 50 in
                  let () = bprintf b "%a" print x in Buffer.contents b
              end
            let _ = let module M = ErrorHandler.Register(Error) in ()
            module Filter =
              struct
                type token_filter = (t, Loc.t) stream_filter
                type t =
                  { is_kwd : string -> bool; mutable filter : token_filter
                  }
                let err error loc =
                  raise (Loc.Exc_located (loc, Error.E error))
                let keyword_conversion tok is_kwd =
                  match tok with
                  | SYMBOL s | LIDENT s | UIDENT s when is_kwd s -> KEYWORD s
                  | ESCAPED_IDENT s -> LIDENT s
                  | _ -> tok
                let check_keyword_as_label tok loc is_kwd =
                  let s =
                    match tok with | LABEL s -> s | OPTLABEL s -> s | _ -> ""
                  in
                    if (s <> "") && (is_kwd s)
                    then err (Error.Keyword_as_label s) loc
                    else ()
                let check_unknown_keywords tok loc =
                  match tok with
                  | SYMBOL s -> err (Error.Illegal_token s) loc
                  | _ -> ()
                let error_no_respect_rules p_con p_prm =
                  raise
                    (Error.E (Error.Illegal_token_pattern (p_con, p_prm)))
                let check_keyword _ = true
                let error_on_unknown_keywords = ref false
                let rec ignore_layout (__strm : _ Stream.t) =
                  match Stream.peek __strm with
                  | Some
                      (((COMMENT _ | BLANKS _ | NEWLINE |
                           LINE_DIRECTIVE (_, _)),
                        _))
                      -> (Stream.junk __strm; ignore_layout __strm)
                  | Some x ->
                      (Stream.junk __strm;
                       let s = __strm
                       in
                         Stream.icons x
                           (Stream.slazy (fun _ -> ignore_layout s)))
                  | _ -> Stream.sempty
                let mk is_kwd = {  is_kwd = is_kwd; filter = ignore_layout; }
                let filter x =
                  let f tok loc =
                    let tok = keyword_conversion tok x.is_kwd
                    in
                      (check_keyword_as_label tok loc x.is_kwd;
                       if !error_on_unknown_keywords
                       then check_unknown_keywords tok loc
                       else ();
                       (tok, loc)) in
                  let rec filter (__strm : _ Stream.t) =
                    match Stream.peek __strm with
                    | Some ((tok, loc)) ->
                        (Stream.junk __strm;
                         let s = __strm
                         in
                           Stream.lcons (fun _ -> f tok loc)
                             (Stream.slazy (fun _ -> filter s)))
                    | _ -> Stream.sempty in
                  let rec tracer (__strm : _ Stream.t) =
                    match Stream.peek __strm with
                    | Some (((_tok, _loc) as x)) ->
                        (Stream.junk __strm;
                         let xs = __strm
                         in
                           Stream.icons x (Stream.slazy (fun _ -> tracer xs)))
                    | _ -> Stream.sempty
                  in fun strm -> tracer (x.filter (filter strm))
                let define_filter x f = x.filter <- f x.filter
                let keyword_added _ _ _ = ()
                let keyword_removed _ _ = ()
              end
          end
        module Eval =
          struct
            let valch x = (Char.code x) - (Char.code '0')
            let valch_hex x =
              let d = Char.code x
              in
                if d >= 97
                then d - 87
                else if d >= 65 then d - 55 else d - 48
            let rec skip_indent (__strm : _ Stream.t) =
              match Stream.peek __strm with
              | Some (' ' | '\t') -> (Stream.junk __strm; skip_indent __strm)
              | _ -> ()
            let skip_opt_linefeed (__strm : _ Stream.t) =
              match Stream.peek __strm with
              | Some '\010' -> (Stream.junk __strm; ())
              | _ -> ()
            let rec backslash (__strm : _ Stream.t) =
              match Stream.peek __strm with
              | Some '\010' -> (Stream.junk __strm; '\010')
              | Some '\013' -> (Stream.junk __strm; '\013')
              | Some 'n' -> (Stream.junk __strm; '\n')
              | Some 'r' -> (Stream.junk __strm; '\r')
              | Some 't' -> (Stream.junk __strm; '\t')
              | Some 'b' -> (Stream.junk __strm; '\b')
              | Some '\\' -> (Stream.junk __strm; '\\')
              | Some '"' -> (Stream.junk __strm; '"')
              | Some '\'' -> (Stream.junk __strm; '\'')
              | Some ' ' -> (Stream.junk __strm; ' ')
              | Some (('0' .. '9' as c1)) ->
                  (Stream.junk __strm;
                   (match Stream.peek __strm with
                    | Some (('0' .. '9' as c2)) ->
                        (Stream.junk __strm;
                         (match Stream.peek __strm with
                          | Some (('0' .. '9' as c3)) ->
                              (Stream.junk __strm;
                               Char.chr
                                 (((100 * (valch c1)) + (10 * (valch c2))) +
                                    (valch c3)))
                          | _ -> raise (Stream.Error "")))
                    | _ -> raise (Stream.Error "")))
              | Some 'x' ->
                  (Stream.junk __strm;
                   (match Stream.peek __strm with
                    | Some (('0' .. '9' | 'a' .. 'f' | 'A' .. 'F' as c1)) ->
                        (Stream.junk __strm;
                         (match Stream.peek __strm with
                          | Some
                              (('0' .. '9' | 'a' .. 'f' | 'A' .. 'F' as c2))
                              ->
                              (Stream.junk __strm;
                               Char.chr
                                 ((16 * (valch_hex c1)) + (valch_hex c2)))
                          | _ -> raise (Stream.Error "")))
                    | _ -> raise (Stream.Error "")))
              | _ -> raise Stream.Failure
            let rec backslash_in_string strict store (__strm : _ Stream.t) =
              match Stream.peek __strm with
              | Some '\010' -> (Stream.junk __strm; skip_indent __strm)
              | Some '\013' ->
                  (Stream.junk __strm;
                   let s = __strm in (skip_opt_linefeed s; skip_indent s))
              | _ ->
                  (match try Some (backslash __strm)
                         with | Stream.Failure -> None
                   with
                   | Some x -> store x
                   | _ ->
                       (match Stream.peek __strm with
                        | Some c when not strict ->
                            (Stream.junk __strm; store '\\'; store c)
                        | _ -> failwith "invalid string token"))
            let char s =
              if (String.length s) = 1
              then s.[0]
              else
                if (String.length s) = 0
                then failwith "invalid char token"
                else
                  (let (__strm : _ Stream.t) = Stream.of_string s
                   in
                     match Stream.peek __strm with
                     | Some '\\' ->
                         (Stream.junk __strm;
                          (try backslash __strm
                           with | Stream.Failure -> raise (Stream.Error "")))
                     | _ -> failwith "invalid char token")
            let string ?strict s =
              let buf = Buffer.create 23 in
              let store = Buffer.add_char buf in
              let rec parse (__strm : _ Stream.t) =
                match Stream.peek __strm with
                | Some '\\' ->
                    (Stream.junk __strm;
                     let _ =
                       (try backslash_in_string (strict <> None) store __strm
                        with | Stream.Failure -> raise (Stream.Error ""))
                     in parse __strm)
                | Some c ->
                    (Stream.junk __strm;
                     let s = __strm in (store c; parse s))
                | _ -> Buffer.contents buf
              in parse (Stream.of_string s)
          end
      end
    module Lexer =
      struct
        module TokenEval = Token.Eval
        module Make (Token : Sig.Camlp4Token) =
          struct
            module Loc = Token.Loc
            module Token = Token
            open Lexing
            open Sig
            module Error =
              struct
                type t =
                  | Illegal_character of char | Illegal_escape of string
                  | Unterminated_comment | Unterminated_string
                  | Unterminated_quotation | Unterminated_antiquot
                  | Unterminated_string_in_comment | Comment_start
                  | Comment_not_end | Literal_overflow of string
                exception E of t
                open Format
                let print ppf =
                  function
                  | Illegal_character c ->
                      fprintf ppf "Illegal character (%s)" (Char.escaped c)
                  | Illegal_escape s ->
                      fprintf ppf
                        "Illegal backslash escape in string or character (%s)"
                        s
                  | Unterminated_comment ->
                      fprintf ppf "Comment not terminated"
                  | Unterminated_string ->
                      fprintf ppf "String literal not terminated"
                  | Unterminated_string_in_comment ->
                      fprintf ppf
                        "This comment contains an unterminated string literal"
                  | Unterminated_quotation ->
                      fprintf ppf "Quotation not terminated"
                  | Unterminated_antiquot ->
                      fprintf ppf "Antiquotation not terminated"
                  | Literal_overflow ty ->
                      fprintf ppf
                        "Integer literal exceeds the range of representable integers of type %s"
                        ty
                  | Comment_start ->
                      fprintf ppf "this is the start of a comment"
                  | Comment_not_end ->
                      fprintf ppf "this is not the end of a comment"
                let to_string x =
                  let b = Buffer.create 50 in
                  let () = bprintf b "%a" print x in Buffer.contents b
              end
            let _ = let module M = ErrorHandler.Register(Error) in ()
            open Error
            type context =
              { loc : Loc.t; in_comment : bool; quotations : bool;
                lexbuf : lexbuf; buffer : Buffer.t
              }
            let default_context lb =
              {
                
                loc = Loc.ghost;
                in_comment = false;
                quotations = true;
                lexbuf = lb;
                buffer = Buffer.create 256;
              }
            let store c = Buffer.add_string c.buffer (Lexing.lexeme c.lexbuf)
            let istore_char c i =
              Buffer.add_char c.buffer (Lexing.lexeme_char c.lexbuf i)
            let buff_contents c =
              let contents = Buffer.contents c.buffer
              in (Buffer.reset c.buffer; contents)
            let loc c = Loc.merge c.loc (Loc.of_lexbuf c.lexbuf)
            let quotations c = c.quotations
            let is_in_comment c = c.in_comment
            let in_comment c = { (c) with  in_comment = true; }
            let set_start_p c = c.lexbuf.lex_start_p <- Loc.start_pos c.loc
            let move_start_p shift c =
              let p = c.lexbuf.lex_start_p
              in
                c.lexbuf.lex_start_p <-
                  { (p) with  pos_cnum = p.pos_cnum + shift; }
            let with_curr_loc f c =
              f { (c) with  loc = Loc.of_lexbuf c.lexbuf; } c.lexbuf
            let parse_nested f c =
              (with_curr_loc f c; set_start_p c; buff_contents c)
            let shift n c = { (c) with  loc = Loc.move `both n c.loc; }
            let store_parse f c = (store c; f c c.lexbuf)
            let parse f c = f c c.lexbuf
            let mk_quotation quotation c name loc shift =
              let s = parse_nested quotation c in
              let contents = String.sub s 0 ((String.length s) - 2)
              in
                QUOTATION
                  {
                    
                    q_name = name;
                    q_loc = loc;
                    q_shift = shift;
                    q_contents = contents;
                  }
            let update_loc c file line absolute chars =
              let lexbuf = c.lexbuf in
              let pos = lexbuf.lex_curr_p in
              let new_file =
                match file with | None -> pos.pos_fname | Some s -> s
              in
                lexbuf.lex_curr_p <-
                  {
                    (pos)
                    with
                    
                    pos_fname = new_file;
                    pos_lnum = if absolute then line else pos.pos_lnum + line;
                    pos_bol = pos.pos_cnum - chars;
                  }
            let err error loc = raise (Loc.Exc_located (loc, Error.E error))
            let warn error loc =
              Format.eprintf "Warning: %a: %a@." Loc.print loc Error.print
                error
            let __ocaml_lex_tables =
              {
                
                Lexing.lex_base =
                  "\000\000\227\255\228\255\001\001\001\001\231\255\232\255\160\001\
    \198\001\067\000\091\000\069\000\071\000\084\000\122\000\235\001\
    \014\002\092\000\102\001\244\255\035\002\068\002\141\002\093\003\
    \060\004\152\004\126\000\001\000\255\255\104\005\253\255\056\006\
    \252\255\245\255\246\255\247\255\023\001\001\001\088\000\091\000\
    \216\002\168\003\179\005\179\001\088\004\132\000\024\007\108\000\
    \151\000\109\000\243\255\242\255\241\255\012\005\033\001\111\000\
    \239\002\193\005\111\000\239\255\238\255\024\007\063\007\109\007\
    \148\007\183\007\174\006\015\003\004\000\233\255\093\001\199\001\
    \151\002\094\001\005\000\233\255\054\008\246\008\006\000\117\004\
    \251\255\208\009\095\000\115\000\115\000\254\255\016\010\207\010\
    \159\011\111\012\079\013\121\000\152\000\124\000\126\000\249\255\
    \248\255\144\006\197\003\127\000\060\004\128\000\200\007\129\000\
    \008\003\007\000\106\013\250\255\054\008\169\004\089\001\082\001\
    \179\004\198\008\054\008\172\013\139\014\169\014\136\015\103\016\
    \135\016\199\016\151\017\254\255\204\001\008\000\107\000\053\001\
    \215\017\150\018\102\019\054\020\018\021\062\001\236\021\197\022\
    \064\001\149\023\248\003\155\001\009\000\213\023\148\024\100\025\
    \052\026";
                Lexing.lex_backtrk =
                  "\255\255\255\255\255\255\028\000\025\000\255\255\255\255\025\000\
    \025\000\023\000\023\000\023\000\023\000\023\000\023\000\025\000\
    \025\000\023\000\023\000\255\255\006\000\006\000\005\000\004\000\
    \025\000\025\000\001\000\000\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\007\000\255\255\255\255\
    \255\255\006\000\006\000\006\000\007\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\014\000\014\000\014\000\
    \255\255\255\255\015\000\255\255\255\255\021\000\020\000\018\000\
    \025\000\019\000\255\255\255\255\022\000\255\255\255\255\255\255\
    \255\255\255\255\022\000\255\255\026\000\255\255\013\000\014\000\
    \255\255\003\000\014\000\014\000\014\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\005\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\006\000\008\000\255\255\005\000\005\000\001\000\001\000\
    \255\255\255\255\000\000\001\000\001\000\255\255\002\000\002\000\
    \255\255\255\255\255\255\255\255\255\255\003\000\004\000\004\000\
    \255\255\255\255\255\255\255\255\255\255\002\000\002\000\002\000\
    \255\255\255\255\255\255\004\000\002\000\255\255\255\255\255\255\
    \255\255";
                Lexing.lex_default =
                  "\001\000\000\000\000\000\076\000\255\255\000\000\000\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\047\000\000\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\000\000\255\255\000\000\255\255\
    \000\000\000\000\000\000\000\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\052\000\255\255\
    \255\255\255\255\000\000\000\000\000\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\000\000\000\000\255\255\255\255\255\255\
    \255\255\255\255\070\000\255\255\255\255\000\000\070\000\071\000\
    \070\000\073\000\255\255\000\000\076\000\052\000\255\255\091\000\
    \000\000\255\255\255\255\255\255\255\255\000\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\000\000\
    \000\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \035\000\255\255\107\000\000\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\000\000\080\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\030\000\255\255\255\255\255\255\
    \255\255\255\255\080\000\255\255\255\255\255\255\255\255\255\255\
    \255\255";
                Lexing.lex_trans =
                  "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\026\000\028\000\028\000\026\000\027\000\069\000\075\000\
    \051\000\095\000\032\000\030\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \026\000\004\000\019\000\014\000\005\000\004\000\004\000\018\000\
    \017\000\006\000\016\000\004\000\006\000\004\000\013\000\004\000\
    \021\000\020\000\020\000\020\000\020\000\020\000\020\000\020\000\
    \020\000\020\000\012\000\011\000\015\000\004\000\007\000\024\000\
    \004\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\010\000\003\000\006\000\004\000\023\000\
    \006\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\009\000\008\000\006\000\025\000\006\000\
    \006\000\006\000\006\000\067\000\006\000\006\000\058\000\026\000\
    \043\000\043\000\026\000\042\000\042\000\042\000\042\000\042\000\
    \042\000\042\000\042\000\051\000\050\000\006\000\051\000\006\000\
    \059\000\087\000\067\000\030\000\085\000\028\000\026\000\086\000\
    \035\000\049\000\093\000\096\000\006\000\095\000\034\000\033\000\
    \019\000\085\000\066\000\066\000\066\000\066\000\066\000\066\000\
    \066\000\066\000\066\000\066\000\044\000\044\000\044\000\044\000\
    \044\000\044\000\044\000\044\000\044\000\044\000\050\000\096\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\006\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\000\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \002\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\004\000\255\255\255\255\004\000\004\000\004\000\
    \000\000\255\255\255\255\004\000\004\000\255\255\004\000\004\000\
    \004\000\037\000\037\000\037\000\037\000\037\000\037\000\037\000\
    \037\000\037\000\037\000\004\000\255\255\004\000\004\000\004\000\
    \004\000\004\000\045\000\000\000\045\000\000\000\036\000\044\000\
    \044\000\044\000\044\000\044\000\044\000\044\000\044\000\044\000\
    \044\000\056\000\056\000\056\000\056\000\056\000\056\000\056\000\
    \056\000\056\000\056\000\111\000\255\255\255\255\255\255\004\000\
    \037\000\255\255\111\000\111\000\000\000\000\000\036\000\069\000\
    \075\000\000\000\068\000\074\000\136\000\000\000\136\000\129\000\
    \049\000\028\000\111\000\048\000\000\000\128\000\000\000\000\000\
    \085\000\111\000\085\000\000\000\255\255\004\000\255\255\004\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\004\000\046\000\000\000\004\000\004\000\004\000\000\000\
    \000\000\000\000\004\000\004\000\000\000\004\000\004\000\004\000\
    \000\000\069\000\000\000\000\000\068\000\142\000\032\000\032\000\
    \255\255\125\000\004\000\141\000\004\000\004\000\004\000\004\000\
    \004\000\000\000\000\000\043\000\043\000\000\000\000\000\004\000\
    \000\000\073\000\004\000\004\000\004\000\000\000\000\000\000\000\
    \004\000\004\000\000\000\004\000\004\000\004\000\000\000\000\000\
    \255\255\000\000\000\000\000\000\000\000\006\000\004\000\034\000\
    \004\000\255\255\004\000\004\000\004\000\004\000\004\000\000\000\
    \127\000\000\000\126\000\000\000\004\000\000\000\000\000\004\000\
    \004\000\004\000\043\000\000\000\000\000\004\000\004\000\000\000\
    \004\000\004\000\004\000\000\000\004\000\006\000\004\000\035\000\
    \000\000\033\000\000\000\006\000\004\000\061\000\000\000\063\000\
    \004\000\004\000\004\000\062\000\000\000\000\000\000\000\004\000\
    \000\000\000\000\004\000\004\000\004\000\000\000\000\000\060\000\
    \004\000\004\000\000\000\004\000\004\000\004\000\000\000\000\000\
    \000\000\000\000\004\000\000\000\004\000\000\000\000\000\000\000\
    \004\000\004\000\004\000\004\000\004\000\004\000\004\000\000\000\
    \000\000\037\000\000\000\020\000\020\000\020\000\020\000\020\000\
    \020\000\020\000\020\000\020\000\020\000\255\255\255\255\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\255\255\004\000\
    \036\000\004\000\000\000\000\000\004\000\000\000\000\000\034\000\
    \000\000\000\000\037\000\000\000\020\000\020\000\020\000\020\000\
    \020\000\020\000\020\000\020\000\020\000\020\000\000\000\000\000\
    \000\000\000\000\020\000\000\000\000\000\000\000\038\000\000\000\
    \036\000\036\000\004\000\000\000\004\000\000\000\000\000\035\000\
    \034\000\033\000\000\000\039\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\040\000\000\000\000\000\000\000\
    \072\000\069\000\000\000\020\000\068\000\000\000\038\000\000\000\
    \000\000\036\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \035\000\000\000\033\000\039\000\022\000\000\000\000\000\072\000\
    \000\000\071\000\000\000\000\000\040\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\255\255\
    \000\000\000\000\000\000\000\000\030\000\000\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \000\000\000\000\000\000\000\000\022\000\000\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \041\000\041\000\041\000\041\000\041\000\041\000\041\000\041\000\
    \041\000\041\000\095\000\000\000\000\000\105\000\000\000\000\000\
    \067\000\041\000\041\000\041\000\041\000\041\000\041\000\047\000\
    \047\000\047\000\047\000\047\000\047\000\047\000\047\000\047\000\
    \047\000\000\000\028\000\000\000\000\000\000\000\000\000\067\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\041\000\041\000\041\000\041\000\041\000\041\000\066\000\
    \066\000\066\000\066\000\066\000\066\000\066\000\066\000\066\000\
    \066\000\000\000\000\000\000\000\000\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\106\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\023\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\255\255\
    \000\000\000\000\000\000\000\000\000\000\000\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \000\000\000\000\000\000\000\000\023\000\000\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \041\000\041\000\041\000\041\000\041\000\041\000\041\000\041\000\
    \041\000\041\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\041\000\041\000\041\000\041\000\041\000\041\000\000\000\
    \000\000\000\000\000\000\000\000\034\000\100\000\100\000\100\000\
    \100\000\100\000\100\000\100\000\100\000\100\000\100\000\000\000\
    \000\000\000\000\030\000\000\000\000\000\140\000\000\000\041\000\
    \096\000\041\000\041\000\041\000\041\000\041\000\041\000\000\000\
    \000\000\000\000\000\000\000\000\035\000\000\000\033\000\000\000\
    \000\000\000\000\000\000\000\000\028\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\139\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\000\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\004\000\000\000\000\000\
    \004\000\004\000\004\000\000\000\000\000\000\000\004\000\004\000\
    \000\000\004\000\004\000\004\000\101\000\101\000\101\000\101\000\
    \101\000\101\000\101\000\101\000\101\000\101\000\004\000\000\000\
    \004\000\004\000\004\000\004\000\004\000\000\000\000\000\093\000\
    \000\000\000\000\092\000\000\000\000\000\000\000\000\000\000\000\
    \044\000\044\000\044\000\044\000\044\000\044\000\044\000\044\000\
    \044\000\044\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\004\000\031\000\094\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\044\000\
    \004\000\004\000\004\000\000\000\004\000\004\000\004\000\000\000\
    \000\000\000\000\004\000\004\000\000\000\004\000\004\000\004\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\090\000\004\000\000\000\004\000\004\000\004\000\004\000\
    \004\000\112\000\112\000\112\000\112\000\112\000\112\000\112\000\
    \112\000\112\000\112\000\032\000\032\000\032\000\032\000\032\000\
    \032\000\032\000\032\000\032\000\032\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\004\000\029\000\
    \085\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\000\000\004\000\000\000\004\000\000\000\
    \000\000\000\000\000\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\000\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\057\000\057\000\057\000\057\000\
    \057\000\057\000\057\000\057\000\057\000\057\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\057\000\057\000\057\000\
    \057\000\057\000\057\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\057\000\057\000\057\000\
    \057\000\057\000\057\000\000\000\000\000\255\255\000\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\030\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\000\000\000\000\000\000\000\000\029\000\
    \000\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\042\000\042\000\042\000\042\000\042\000\
    \042\000\042\000\042\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\047\000\047\000\047\000\047\000\047\000\047\000\047\000\
    \047\000\047\000\047\000\000\000\000\000\000\000\000\000\034\000\
    \000\000\000\000\047\000\047\000\047\000\047\000\047\000\047\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\042\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\035\000\
    \000\000\033\000\047\000\047\000\047\000\047\000\047\000\047\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\000\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\031\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\032\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\000\000\000\000\000\000\000\000\031\000\
    \000\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\000\000\000\000\000\000\000\000\072\000\
    \069\000\000\000\000\000\068\000\000\000\000\000\000\000\000\000\
    \102\000\102\000\102\000\102\000\102\000\102\000\102\000\102\000\
    \102\000\102\000\000\000\000\000\000\000\000\000\072\000\000\000\
    \071\000\102\000\102\000\102\000\102\000\102\000\102\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\066\000\066\000\
    \066\000\066\000\066\000\066\000\066\000\066\000\066\000\066\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\102\000\102\000\102\000\102\000\102\000\102\000\000\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\000\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\000\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \055\000\004\000\055\000\000\000\004\000\004\000\004\000\055\000\
    \000\000\000\000\004\000\004\000\000\000\004\000\004\000\004\000\
    \054\000\054\000\054\000\054\000\054\000\054\000\054\000\054\000\
    \054\000\054\000\004\000\000\000\004\000\004\000\004\000\004\000\
    \004\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \004\000\000\000\000\000\004\000\004\000\004\000\000\000\000\000\
    \000\000\004\000\004\000\000\000\004\000\004\000\004\000\000\000\
    \000\000\000\000\000\000\000\000\055\000\000\000\004\000\000\000\
    \000\000\004\000\055\000\004\000\004\000\004\000\004\000\004\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\055\000\000\000\
    \000\000\000\000\055\000\000\000\055\000\000\000\004\000\000\000\
    \053\000\004\000\004\000\004\000\004\000\000\000\004\000\004\000\
    \004\000\000\000\004\000\004\000\004\000\004\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\004\000\
    \000\000\004\000\004\000\064\000\004\000\004\000\255\255\000\000\
    \000\000\000\000\000\000\000\000\000\000\004\000\000\000\000\000\
    \004\000\004\000\004\000\004\000\000\000\004\000\004\000\004\000\
    \000\000\004\000\004\000\004\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\004\000\000\000\000\000\004\000\000\000\
    \004\000\004\000\065\000\004\000\004\000\000\000\000\000\000\000\
    \004\000\000\000\000\000\004\000\004\000\004\000\000\000\000\000\
    \000\000\004\000\004\000\000\000\004\000\004\000\004\000\000\000\
    \000\000\004\000\000\000\004\000\000\000\000\000\000\000\000\000\
    \000\000\004\000\004\000\004\000\004\000\004\000\004\000\004\000\
    \103\000\103\000\103\000\103\000\103\000\103\000\103\000\103\000\
    \103\000\103\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\103\000\103\000\103\000\103\000\103\000\103\000\000\000\
    \004\000\000\000\004\000\000\000\000\000\004\000\000\000\000\000\
    \255\255\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\103\000\103\000\103\000\103\000\103\000\103\000\000\000\
    \000\000\000\000\000\000\004\000\000\000\004\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\114\000\
    \255\255\255\255\114\000\114\000\114\000\000\000\255\255\255\255\
    \114\000\114\000\255\255\114\000\114\000\114\000\113\000\113\000\
    \113\000\113\000\113\000\113\000\113\000\113\000\113\000\113\000\
    \114\000\255\255\114\000\114\000\114\000\114\000\114\000\113\000\
    \113\000\113\000\113\000\113\000\113\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\255\255\255\255\255\255\114\000\000\000\255\255\113\000\
    \113\000\113\000\113\000\113\000\113\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\255\255\114\000\255\255\114\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\080\000\080\000\
    \080\000\080\000\080\000\080\000\080\000\080\000\080\000\080\000\
    \051\000\000\000\000\000\078\000\000\000\000\000\000\000\080\000\
    \080\000\080\000\080\000\080\000\080\000\255\255\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \080\000\000\000\000\000\000\000\000\000\079\000\084\000\000\000\
    \083\000\000\000\000\000\000\000\000\000\000\000\000\000\080\000\
    \080\000\080\000\080\000\080\000\080\000\255\255\000\000\000\000\
    \000\000\000\000\082\000\000\000\000\000\000\000\255\255\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\000\000\000\000\000\000\000\000\081\000\000\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\000\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\000\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\050\000\081\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\000\000\000\000\000\000\000\000\081\000\
    \000\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\000\000\000\000\000\000\000\000\089\000\
    \000\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\000\000\000\000\000\000\000\000\000\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\000\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\000\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\000\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\000\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\000\000\000\000\000\000\000\000\088\000\000\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\000\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\000\000\000\000\030\000\000\000\000\000\000\000\086\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\000\000\000\000\000\000\000\000\088\000\000\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\000\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\089\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\000\000\000\000\030\000\000\000\000\000\000\000\000\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\000\000\000\000\000\000\000\000\089\000\000\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\000\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\000\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\099\000\
    \000\000\099\000\000\000\000\000\111\000\000\000\099\000\110\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\098\000\
    \098\000\098\000\098\000\098\000\098\000\098\000\098\000\098\000\
    \098\000\000\000\030\000\000\000\030\000\000\000\000\000\000\000\
    \000\000\030\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\109\000\109\000\109\000\109\000\109\000\109\000\
    \109\000\109\000\109\000\109\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\099\000\000\000\000\000\000\000\000\000\
    \000\000\099\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\099\000\000\000\000\000\
    \000\000\099\000\000\000\099\000\000\000\000\000\030\000\097\000\
    \000\000\000\000\000\000\000\000\030\000\116\000\000\000\000\000\
    \116\000\116\000\116\000\000\000\000\000\000\000\116\000\116\000\
    \030\000\116\000\116\000\116\000\030\000\000\000\030\000\000\000\
    \000\000\000\000\108\000\000\000\000\000\000\000\116\000\000\000\
    \116\000\116\000\116\000\116\000\116\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\000\000\
    \000\000\000\000\116\000\117\000\000\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\000\000\
    \116\000\000\000\116\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\255\255\000\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\000\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\000\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\116\000\000\000\000\000\116\000\
    \116\000\116\000\000\000\000\000\000\000\116\000\116\000\000\000\
    \116\000\116\000\116\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\116\000\000\000\116\000\
    \116\000\116\000\116\000\116\000\000\000\000\000\000\000\000\000\
    \117\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\000\000\000\000\028\000\000\000\000\000\
    \000\000\116\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\000\000\000\000\000\000\116\000\
    \117\000\116\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \000\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \000\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\119\000\000\000\000\000\119\000\119\000\119\000\000\000\
    \000\000\000\000\119\000\119\000\000\000\119\000\119\000\119\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\119\000\000\000\119\000\119\000\119\000\119\000\
    \119\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\000\000\000\000\000\000\119\000\120\000\
    \000\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\000\000\119\000\000\000\119\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\000\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\000\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \119\000\000\000\000\000\119\000\119\000\119\000\000\000\000\000\
    \000\000\119\000\119\000\000\000\119\000\119\000\119\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\119\000\000\000\119\000\119\000\119\000\119\000\119\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\120\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\000\000\000\000\028\000\000\000\119\000\000\000\121\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\000\000\119\000\000\000\119\000\120\000\000\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\000\000\000\000\000\000\000\000\122\000\000\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\000\000\000\000\000\000\000\000\000\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\000\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\000\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\000\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\000\000\000\000\123\000\000\000\000\000\000\000\000\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\000\000\000\000\000\000\000\000\122\000\000\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\000\000\000\000\000\000\000\000\131\000\000\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\000\000\000\000\000\000\000\000\000\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\000\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\000\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\000\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\000\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\000\000\000\000\000\000\000\000\130\000\000\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\000\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \000\000\000\000\028\000\000\000\000\000\000\000\128\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\000\000\000\000\000\000\000\000\130\000\000\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\000\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\131\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \000\000\000\000\028\000\000\000\000\000\000\000\000\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\000\000\000\000\000\000\000\000\131\000\000\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\000\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\000\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\028\000\000\000\
    \000\000\134\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \133\000\000\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\085\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\000\000\000\000\000\000\
    \000\000\134\000\135\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\000\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\000\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\255\255\137\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\085\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\000\000\
    \000\000\000\000\000\000\137\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\000\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\000\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\136\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\085\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \000\000\000\000\000\000\000\000\137\000\000\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\085\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \000\000\000\000\000\000\000\000\137\000\000\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \000\000\000\000\000\000\000\000\144\000\000\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \000\000\000\000\000\000\000\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\000\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\000\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\000\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\000\000\
    \000\000\000\000\000\000\143\000\000\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\000\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\000\000\000\000\
    \032\000\000\000\000\000\000\000\141\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\000\000\
    \000\000\000\000\000\000\143\000\000\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\000\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\144\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\000\000\000\000\
    \032\000\000\000\000\000\000\000\000\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\000\000\
    \000\000\000\000\000\000\144\000\000\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\000\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\000\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\000\000";
                Lexing.lex_check =
                  "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\000\000\000\000\027\000\000\000\000\000\068\000\074\000\
    \078\000\105\000\125\000\140\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\009\000\
    \011\000\012\000\013\000\014\000\012\000\012\000\017\000\026\000\
    \038\000\038\000\026\000\039\000\039\000\039\000\039\000\039\000\
    \039\000\039\000\039\000\047\000\049\000\010\000\055\000\010\000\
    \058\000\082\000\014\000\082\000\083\000\084\000\026\000\082\000\
    \091\000\048\000\092\000\093\000\012\000\094\000\099\000\101\000\
    \103\000\126\000\014\000\014\000\014\000\014\000\014\000\014\000\
    \014\000\014\000\014\000\014\000\045\000\045\000\045\000\045\000\
    \045\000\045\000\045\000\045\000\045\000\045\000\048\000\092\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\010\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\255\255\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\004\000\003\000\003\000\004\000\004\000\004\000\
    \255\255\003\000\003\000\004\000\004\000\003\000\004\000\004\000\
    \004\000\037\000\037\000\037\000\037\000\037\000\037\000\037\000\
    \037\000\037\000\037\000\004\000\003\000\004\000\004\000\004\000\
    \004\000\004\000\036\000\255\255\036\000\255\255\037\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\054\000\054\000\054\000\054\000\054\000\054\000\054\000\
    \054\000\054\000\054\000\111\000\003\000\003\000\003\000\004\000\
    \037\000\003\000\110\000\110\000\255\255\255\255\037\000\070\000\
    \073\000\255\255\070\000\073\000\133\000\255\255\136\000\127\000\
    \018\000\127\000\111\000\018\000\255\255\127\000\255\255\255\255\
    \133\000\110\000\136\000\255\255\003\000\004\000\003\000\004\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\007\000\018\000\255\255\007\000\007\000\007\000\255\255\
    \255\255\255\255\007\000\007\000\255\255\007\000\007\000\007\000\
    \255\255\071\000\255\255\255\255\071\000\139\000\124\000\139\000\
    \003\000\124\000\007\000\139\000\007\000\007\000\007\000\007\000\
    \007\000\255\255\255\255\043\000\043\000\255\255\255\255\008\000\
    \255\255\071\000\008\000\008\000\008\000\255\255\255\255\255\255\
    \008\000\008\000\255\255\008\000\008\000\008\000\255\255\255\255\
    \003\000\255\255\255\255\255\255\255\255\007\000\007\000\043\000\
    \008\000\003\000\008\000\008\000\008\000\008\000\008\000\255\255\
    \124\000\255\255\124\000\255\255\015\000\255\255\255\255\015\000\
    \015\000\015\000\043\000\255\255\255\255\015\000\015\000\255\255\
    \015\000\015\000\015\000\255\255\007\000\007\000\007\000\043\000\
    \255\255\043\000\255\255\008\000\008\000\015\000\255\255\015\000\
    \015\000\015\000\015\000\015\000\255\255\255\255\255\255\016\000\
    \255\255\255\255\016\000\016\000\016\000\255\255\255\255\016\000\
    \016\000\016\000\255\255\016\000\016\000\016\000\255\255\255\255\
    \255\255\255\255\008\000\255\255\008\000\255\255\255\255\255\255\
    \016\000\015\000\016\000\016\000\016\000\016\000\016\000\255\255\
    \255\255\020\000\255\255\020\000\020\000\020\000\020\000\020\000\
    \020\000\020\000\020\000\020\000\020\000\070\000\073\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\018\000\015\000\
    \020\000\015\000\255\255\255\255\016\000\255\255\255\255\020\000\
    \255\255\255\255\021\000\255\255\021\000\021\000\021\000\021\000\
    \021\000\021\000\021\000\021\000\021\000\021\000\255\255\255\255\
    \255\255\255\255\020\000\255\255\255\255\255\255\021\000\255\255\
    \020\000\021\000\016\000\255\255\016\000\255\255\255\255\020\000\
    \021\000\020\000\255\255\021\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\021\000\255\255\255\255\255\255\
    \072\000\072\000\255\255\021\000\072\000\255\255\021\000\255\255\
    \255\255\021\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \021\000\255\255\021\000\021\000\022\000\255\255\255\255\072\000\
    \255\255\072\000\255\255\255\255\021\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\071\000\
    \255\255\255\255\255\255\255\255\124\000\255\255\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \255\255\255\255\255\255\255\255\022\000\255\255\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \040\000\040\000\040\000\040\000\040\000\040\000\040\000\040\000\
    \040\000\040\000\104\000\255\255\255\255\104\000\255\255\255\255\
    \067\000\040\000\040\000\040\000\040\000\040\000\040\000\056\000\
    \056\000\056\000\056\000\056\000\056\000\056\000\056\000\056\000\
    \056\000\255\255\104\000\255\255\255\255\255\255\255\255\067\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\040\000\040\000\040\000\040\000\040\000\040\000\067\000\
    \067\000\067\000\067\000\067\000\067\000\067\000\067\000\067\000\
    \067\000\255\255\255\255\255\255\255\255\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\104\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\023\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\072\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \255\255\255\255\255\255\255\255\023\000\255\255\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \041\000\041\000\041\000\041\000\041\000\041\000\041\000\041\000\
    \041\000\041\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\041\000\041\000\041\000\041\000\041\000\041\000\255\255\
    \255\255\255\255\255\255\255\255\041\000\098\000\098\000\098\000\
    \098\000\098\000\098\000\098\000\098\000\098\000\098\000\255\255\
    \255\255\255\255\138\000\255\255\255\255\138\000\255\255\041\000\
    \104\000\041\000\041\000\041\000\041\000\041\000\041\000\255\255\
    \255\255\255\255\255\255\255\255\041\000\255\255\041\000\255\255\
    \255\255\255\255\255\255\255\255\138\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\138\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\255\255\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\024\000\255\255\255\255\
    \024\000\024\000\024\000\255\255\255\255\255\255\024\000\024\000\
    \255\255\024\000\024\000\024\000\100\000\100\000\100\000\100\000\
    \100\000\100\000\100\000\100\000\100\000\100\000\024\000\255\255\
    \024\000\024\000\024\000\024\000\024\000\255\255\255\255\079\000\
    \255\255\255\255\079\000\255\255\255\255\255\255\255\255\255\255\
    \044\000\044\000\044\000\044\000\044\000\044\000\044\000\044\000\
    \044\000\044\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\024\000\024\000\079\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\024\000\024\000\044\000\
    \024\000\025\000\024\000\255\255\025\000\025\000\025\000\255\255\
    \255\255\255\255\025\000\025\000\255\255\025\000\025\000\025\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\079\000\025\000\255\255\025\000\025\000\025\000\025\000\
    \025\000\109\000\109\000\109\000\109\000\109\000\109\000\109\000\
    \109\000\109\000\109\000\112\000\112\000\112\000\112\000\112\000\
    \112\000\112\000\112\000\112\000\112\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\025\000\025\000\
    \138\000\025\000\025\000\025\000\025\000\025\000\025\000\025\000\
    \025\000\025\000\025\000\025\000\025\000\025\000\025\000\025\000\
    \025\000\025\000\025\000\025\000\025\000\025\000\025\000\025\000\
    \025\000\025\000\025\000\255\255\025\000\255\255\025\000\255\255\
    \255\255\255\255\255\255\024\000\024\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\255\255\024\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\053\000\053\000\053\000\053\000\
    \053\000\053\000\053\000\053\000\053\000\053\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\053\000\053\000\053\000\
    \053\000\053\000\053\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\053\000\053\000\053\000\
    \053\000\053\000\053\000\255\255\255\255\079\000\255\255\025\000\
    \025\000\025\000\025\000\025\000\025\000\025\000\025\000\025\000\
    \025\000\025\000\025\000\025\000\025\000\025\000\025\000\025\000\
    \025\000\025\000\025\000\025\000\025\000\025\000\025\000\029\000\
    \025\000\025\000\025\000\025\000\025\000\025\000\025\000\025\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\255\255\255\255\255\255\255\255\029\000\
    \255\255\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\042\000\042\000\042\000\042\000\042\000\
    \042\000\042\000\042\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\057\000\057\000\057\000\057\000\057\000\057\000\057\000\
    \057\000\057\000\057\000\255\255\255\255\255\255\255\255\042\000\
    \255\255\255\255\057\000\057\000\057\000\057\000\057\000\057\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\042\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\042\000\
    \255\255\042\000\057\000\057\000\057\000\057\000\057\000\057\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\255\255\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\031\000\
    \029\000\029\000\029\000\029\000\029\000\029\000\029\000\029\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\255\255\255\255\255\255\255\255\031\000\
    \255\255\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\255\255\255\255\255\255\255\255\066\000\
    \066\000\255\255\255\255\066\000\255\255\255\255\255\255\255\255\
    \097\000\097\000\097\000\097\000\097\000\097\000\097\000\097\000\
    \097\000\097\000\255\255\255\255\255\255\255\255\066\000\255\255\
    \066\000\097\000\097\000\097\000\097\000\097\000\097\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\066\000\066\000\
    \066\000\066\000\066\000\066\000\066\000\066\000\066\000\066\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\097\000\097\000\097\000\097\000\097\000\097\000\255\255\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\255\255\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\255\255\
    \031\000\031\000\031\000\031\000\031\000\031\000\031\000\031\000\
    \046\000\061\000\046\000\255\255\061\000\061\000\061\000\046\000\
    \255\255\255\255\061\000\061\000\255\255\061\000\061\000\061\000\
    \046\000\046\000\046\000\046\000\046\000\046\000\046\000\046\000\
    \046\000\046\000\061\000\255\255\061\000\061\000\061\000\061\000\
    \061\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \062\000\255\255\255\255\062\000\062\000\062\000\255\255\255\255\
    \255\255\062\000\062\000\255\255\062\000\062\000\062\000\255\255\
    \255\255\255\255\255\255\255\255\046\000\255\255\061\000\255\255\
    \255\255\062\000\046\000\062\000\062\000\062\000\062\000\062\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\046\000\255\255\
    \255\255\255\255\046\000\255\255\046\000\255\255\063\000\255\255\
    \046\000\063\000\063\000\063\000\061\000\255\255\061\000\063\000\
    \063\000\255\255\063\000\063\000\063\000\062\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\063\000\
    \255\255\063\000\063\000\063\000\063\000\063\000\066\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\064\000\255\255\255\255\
    \064\000\064\000\064\000\062\000\255\255\062\000\064\000\064\000\
    \255\255\064\000\064\000\064\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\063\000\255\255\255\255\064\000\255\255\
    \064\000\064\000\064\000\064\000\064\000\255\255\255\255\255\255\
    \065\000\255\255\255\255\065\000\065\000\065\000\255\255\255\255\
    \255\255\065\000\065\000\255\255\065\000\065\000\065\000\255\255\
    \255\255\063\000\255\255\063\000\255\255\255\255\255\255\255\255\
    \255\255\065\000\064\000\065\000\065\000\065\000\065\000\065\000\
    \102\000\102\000\102\000\102\000\102\000\102\000\102\000\102\000\
    \102\000\102\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\102\000\102\000\102\000\102\000\102\000\102\000\255\255\
    \064\000\255\255\064\000\255\255\255\255\065\000\255\255\255\255\
    \046\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\102\000\102\000\102\000\102\000\102\000\102\000\255\255\
    \255\255\255\255\255\255\065\000\255\255\065\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\114\000\
    \076\000\076\000\114\000\114\000\114\000\255\255\076\000\076\000\
    \114\000\114\000\076\000\114\000\114\000\114\000\108\000\108\000\
    \108\000\108\000\108\000\108\000\108\000\108\000\108\000\108\000\
    \114\000\076\000\114\000\114\000\114\000\114\000\114\000\108\000\
    \108\000\108\000\108\000\108\000\108\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\076\000\076\000\076\000\114\000\255\255\076\000\108\000\
    \108\000\108\000\108\000\108\000\108\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\076\000\114\000\076\000\114\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\076\000\076\000\
    \076\000\076\000\076\000\076\000\076\000\076\000\113\000\113\000\
    \113\000\113\000\113\000\113\000\113\000\113\000\113\000\113\000\
    \077\000\255\255\255\255\077\000\255\255\255\255\255\255\113\000\
    \113\000\113\000\113\000\113\000\113\000\076\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \077\000\255\255\255\255\255\255\255\255\077\000\077\000\255\255\
    \077\000\255\255\255\255\255\255\255\255\255\255\255\255\113\000\
    \113\000\113\000\113\000\113\000\113\000\076\000\255\255\255\255\
    \255\255\255\255\077\000\255\255\255\255\255\255\076\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\255\255\255\255\255\255\255\255\077\000\255\255\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\255\255\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\255\255\077\000\077\000\
    \077\000\077\000\077\000\077\000\077\000\077\000\077\000\081\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\255\255\255\255\255\255\255\255\081\000\
    \255\255\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\255\255\255\255\255\255\255\255\086\000\
    \255\255\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\255\255\255\255\255\255\255\255\255\255\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\255\255\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\255\255\
    \081\000\081\000\081\000\081\000\081\000\081\000\081\000\081\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\255\255\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\255\255\
    \086\000\086\000\086\000\086\000\086\000\086\000\086\000\086\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\255\255\255\255\255\255\255\255\087\000\255\255\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\255\255\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\088\000\087\000\
    \087\000\087\000\087\000\087\000\087\000\087\000\087\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\255\255\255\255\088\000\255\255\255\255\255\255\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\255\255\255\255\255\255\255\255\088\000\255\255\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\255\255\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\089\000\088\000\
    \088\000\088\000\088\000\088\000\088\000\088\000\088\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\255\255\255\255\089\000\255\255\255\255\255\255\255\255\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\255\255\255\255\255\255\255\255\089\000\255\255\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\255\255\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\255\255\089\000\
    \089\000\089\000\089\000\089\000\089\000\089\000\089\000\090\000\
    \255\255\090\000\255\255\255\255\106\000\255\255\090\000\106\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\090\000\
    \090\000\090\000\090\000\090\000\090\000\090\000\090\000\090\000\
    \090\000\255\255\106\000\255\255\106\000\255\255\255\255\255\255\
    \255\255\106\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\106\000\106\000\106\000\106\000\106\000\106\000\
    \106\000\106\000\106\000\106\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\090\000\255\255\255\255\255\255\255\255\
    \255\255\090\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\090\000\255\255\255\255\
    \255\255\090\000\255\255\090\000\255\255\255\255\106\000\090\000\
    \255\255\255\255\255\255\255\255\106\000\115\000\255\255\255\255\
    \115\000\115\000\115\000\255\255\255\255\255\255\115\000\115\000\
    \106\000\115\000\115\000\115\000\106\000\255\255\106\000\255\255\
    \255\255\255\255\106\000\255\255\255\255\255\255\115\000\255\255\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\255\255\
    \255\255\255\255\115\000\115\000\255\255\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\255\255\
    \115\000\255\255\115\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\106\000\255\255\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\255\255\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\255\255\115\000\115\000\115\000\115\000\
    \115\000\115\000\115\000\115\000\116\000\255\255\255\255\116\000\
    \116\000\116\000\255\255\255\255\255\255\116\000\116\000\255\255\
    \116\000\116\000\116\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\116\000\255\255\116\000\
    \116\000\116\000\116\000\116\000\255\255\255\255\255\255\255\255\
    \117\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\255\255\255\255\117\000\255\255\255\255\
    \255\255\116\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\255\255\255\255\255\255\116\000\
    \117\000\116\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \255\255\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \255\255\117\000\117\000\117\000\117\000\117\000\117\000\117\000\
    \117\000\118\000\255\255\255\255\118\000\118\000\118\000\255\255\
    \255\255\255\255\118\000\118\000\255\255\118\000\118\000\118\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\118\000\255\255\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\255\255\255\255\255\255\118\000\118\000\
    \255\255\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\255\255\118\000\255\255\118\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\255\255\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\255\255\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \119\000\255\255\255\255\119\000\119\000\119\000\255\255\255\255\
    \255\255\119\000\119\000\255\255\119\000\119\000\119\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\119\000\255\255\119\000\119\000\119\000\119\000\119\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\120\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\255\255\255\255\120\000\255\255\119\000\255\255\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\255\255\119\000\255\255\119\000\120\000\255\255\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\255\255\255\255\255\255\255\255\121\000\255\255\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\255\255\255\255\255\255\255\255\255\255\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\255\255\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\255\255\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\255\255\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\122\000\121\000\
    \121\000\121\000\121\000\121\000\121\000\121\000\121\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\255\255\255\255\122\000\255\255\255\255\255\255\255\255\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\255\255\255\255\255\255\255\255\122\000\255\255\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\255\255\255\255\255\255\255\255\128\000\255\255\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\255\255\255\255\255\255\255\255\255\255\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\255\255\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\255\255\122\000\
    \122\000\122\000\122\000\122\000\122\000\122\000\122\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\255\255\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\255\255\128\000\
    \128\000\128\000\128\000\128\000\128\000\128\000\128\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\255\255\255\255\255\255\255\255\129\000\255\255\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\255\255\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\130\000\129\000\129\000\
    \129\000\129\000\129\000\129\000\129\000\129\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \255\255\255\255\130\000\255\255\255\255\255\255\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\255\255\255\255\255\255\255\255\130\000\255\255\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\255\255\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\131\000\130\000\130\000\
    \130\000\130\000\130\000\130\000\130\000\130\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \255\255\255\255\131\000\255\255\255\255\255\255\255\255\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\255\255\255\255\255\255\255\255\131\000\255\255\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\255\255\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\255\255\131\000\131\000\
    \131\000\131\000\131\000\131\000\131\000\131\000\132\000\255\255\
    \255\255\132\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \132\000\255\255\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\255\255\255\255\255\255\
    \255\255\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\255\255\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\255\255\132\000\132\000\132\000\132\000\132\000\132\000\
    \132\000\132\000\132\000\134\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\255\255\
    \255\255\255\255\255\255\134\000\255\255\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\255\255\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\255\255\134\000\134\000\134\000\134\000\
    \134\000\134\000\134\000\134\000\135\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\135\000\255\255\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \255\255\255\255\255\255\255\255\135\000\255\255\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\255\255\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\137\000\135\000\135\000\135\000\
    \135\000\135\000\135\000\135\000\135\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \255\255\255\255\255\255\255\255\137\000\255\255\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \255\255\255\255\255\255\255\255\141\000\255\255\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \255\255\255\255\255\255\255\255\255\255\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\255\255\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\255\255\137\000\137\000\137\000\
    \137\000\137\000\137\000\137\000\137\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\255\255\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\255\255\141\000\141\000\141\000\
    \141\000\141\000\141\000\141\000\141\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\255\255\
    \255\255\255\255\255\255\142\000\255\255\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\255\255\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\143\000\142\000\142\000\142\000\142\000\
    \142\000\142\000\142\000\142\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\255\255\255\255\
    \143\000\255\255\255\255\255\255\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\255\255\
    \255\255\255\255\255\255\143\000\255\255\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\255\255\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\144\000\143\000\143\000\143\000\143\000\
    \143\000\143\000\143\000\143\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\255\255\255\255\
    \144\000\255\255\255\255\255\255\255\255\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\255\255\
    \255\255\255\255\255\255\144\000\255\255\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\255\255\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\255\255\144\000\144\000\144\000\144\000\
    \144\000\144\000\144\000\144\000\255\255";
                Lexing.lex_base_code =
                  "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\010\000\036\000\000\000\012\000\000\000\000\000\
    \002\000\000\000\000\000\027\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\001\000\000\000\000\000\000\000\002\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\041\000\000\000\
    \249\000\000\000\000\000\039\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000";
                Lexing.lex_backtrk_code =
                  "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\012\000\000\000\000\000\000\000\
    \000\000\000\000\027\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\039\000\039\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000";
                Lexing.lex_default_code =
                  "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\019\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000";
                Lexing.lex_trans_code =
                  "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\001\000\000\000\036\000\036\000\000\000\036\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \001\000\000\000\000\000\001\000\022\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\007\000\001\000\000\000\000\000\
    \004\000\004\000\004\000\004\000\004\000\004\000\004\000\004\000\
    \004\000\004\000\004\000\004\000\004\000\004\000\004\000\004\000\
    \004\000\004\000\004\000\004\000\001\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\004\000\004\000\004\000\004\000\
    \004\000\004\000\004\000\004\000\004\000\004\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\000\000\000\000\000\000\000\000\
    \036\000\000\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \000\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\000\000\000\000\000\000\000\000\
    \036\000\000\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \000\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \000\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\000\000";
                Lexing.lex_check_code =
                  "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\014\000\071\000\106\000\110\000\071\000\106\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \014\000\255\255\071\000\000\000\072\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\066\000\067\000\255\255\255\255\
    \014\000\014\000\014\000\014\000\014\000\014\000\014\000\014\000\
    \014\000\014\000\066\000\066\000\066\000\066\000\066\000\066\000\
    \066\000\066\000\066\000\066\000\067\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\067\000\067\000\067\000\067\000\
    \067\000\067\000\067\000\067\000\067\000\067\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\255\255\255\255\255\255\255\255\
    \118\000\255\255\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \071\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \120\000\118\000\118\000\118\000\118\000\118\000\118\000\118\000\
    \118\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\255\255\255\255\255\255\255\255\
    \120\000\255\255\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \255\255\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \255\255\120\000\120\000\120\000\120\000\120\000\120\000\120\000\
    \120\000\255\255";
                Lexing.lex_code =
                  "\255\004\255\255\005\255\255\007\255\006\255\255\003\255\000\004\
    \001\005\255\007\255\255\006\255\007\255\255\000\004\001\005\003\
    \006\002\007\255\001\255\255\000\001\255";
              }
            let rec token c lexbuf =
              (lexbuf.Lexing.lex_mem <- Array.create 8 (-1);
               __ocaml_lex_token_rec c lexbuf 0)
            and __ocaml_lex_token_rec c lexbuf __ocaml_lex_state =
              match Lexing.new_engine __ocaml_lex_tables __ocaml_lex_state
                      lexbuf
              with
              | 0 -> (update_loc c None 1 false 0; NEWLINE)
              | 1 ->
                  let x =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in BLANKS x
              | 2 ->
                  let x =
                    Lexing.sub_lexeme lexbuf
                      (lexbuf.Lexing.lex_start_pos + 1)
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in LABEL x
              | 3 ->
                  let x =
                    Lexing.sub_lexeme lexbuf
                      (lexbuf.Lexing.lex_start_pos + 1)
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in OPTLABEL x
              | 4 ->
                  let x =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in LIDENT x
              | 5 ->
                  let x =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in UIDENT x
              | 6 ->
                  let i =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in
                    (try INT (int_of_string i, i)
                     with
                     | Failure _ ->
                         err (Literal_overflow "int") (Loc.of_lexbuf lexbuf))
              | 7 ->
                  let f =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in
                    (try FLOAT (float_of_string f, f)
                     with
                     | Failure _ ->
                         err (Literal_overflow "float")
                           (Loc.of_lexbuf lexbuf))
              | 8 ->
                  let i =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    (try INT32 (Int32.of_string i, i)
                     with
                     | Failure _ ->
                         err (Literal_overflow "int32")
                           (Loc.of_lexbuf lexbuf))
              | 9 ->
                  let i =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    (try INT64 (Int64.of_string i, i)
                     with
                     | Failure _ ->
                         err (Literal_overflow "int64")
                           (Loc.of_lexbuf lexbuf))
              | 10 ->
                  let i =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    (try NATIVEINT (Nativeint.of_string i, i)
                     with
                     | Failure _ ->
                         err (Literal_overflow "nativeint")
                           (Loc.of_lexbuf lexbuf))
              | 11 ->
                  (with_curr_loc string c;
                   let s = buff_contents c in STRING (TokenEval.string s, s))
              | 12 ->
                  let x =
                    Lexing.sub_lexeme lexbuf
                      (lexbuf.Lexing.lex_start_pos + 1)
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    (update_loc c None 1 false 1; CHAR (TokenEval.char x, x))
              | 13 ->
                  let x =
                    Lexing.sub_lexeme lexbuf
                      (lexbuf.Lexing.lex_start_pos + 1)
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in CHAR (TokenEval.char x, x)
              | 14 ->
                  let c =
                    Lexing.sub_lexeme_char lexbuf
                      (lexbuf.Lexing.lex_start_pos + 2)
                  in
                    err (Illegal_escape (String.make 1 c))
                      (Loc.of_lexbuf lexbuf)
              | 15 ->
                  (store c; COMMENT (parse_nested comment (in_comment c)))
              | 16 ->
                  (warn Comment_start (Loc.of_lexbuf lexbuf);
                   parse comment (in_comment c);
                   COMMENT (buff_contents c))
              | 17 ->
                  (warn Comment_not_end (Loc.of_lexbuf lexbuf);
                   move_start_p (-1) c;
                   SYMBOL "*")
              | 18 ->
                  if quotations c
                  then mk_quotation quotation c "" "" 2
                  else parse (symbolchar_star "<<") c
              | 19 ->
                  if quotations c
                  then
                    QUOTATION
                      {
                        
                        q_name = "";
                        q_loc = "";
                        q_shift = 2;
                        q_contents = "";
                      }
                  else parse (symbolchar_star "<<>>") c
              | 20 ->
                  if quotations c
                  then with_curr_loc maybe_quotation_at c
                  else parse (symbolchar_star "<@") c
              | 21 ->
                  if quotations c
                  then with_curr_loc maybe_quotation_colon c
                  else parse (symbolchar_star "<:") c
              | 22 ->
                  let num =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_mem.(0)
                      lexbuf.Lexing.lex_mem.(1)
                  and name =
                    Lexing.sub_lexeme_opt lexbuf lexbuf.Lexing.lex_mem.(3)
                      lexbuf.Lexing.lex_mem.(2) in
                  let inum = int_of_string num
                  in
                    (update_loc c name inum true 0;
                     LINE_DIRECTIVE (inum, name))
              | 23 ->
                  let x =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in SYMBOL x
              | 24 ->
                  if quotations c
                  then with_curr_loc dollar (shift 1 c)
                  else parse (symbolchar_star "$") c
              | 25 ->
                  let x =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in SYMBOL x
              | 26 ->
                  let x =
                    Lexing.sub_lexeme lexbuf
                      (lexbuf.Lexing.lex_start_pos + 1)
                      lexbuf.Lexing.lex_curr_pos
                  in ESCAPED_IDENT x
              | 27 ->
                  let pos = lexbuf.lex_curr_p
                  in
                    (lexbuf.lex_curr_p <-
                       {
                         (pos)
                         with
                         
                         pos_bol = pos.pos_bol + 1;
                         pos_cnum = pos.pos_cnum + 1;
                       };
                     EOI)
              | 28 ->
                  let c =
                    Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos
                  in err (Illegal_character c) (Loc.of_lexbuf lexbuf)
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_token_rec c lexbuf __ocaml_lex_state)
            and comment c lexbuf = __ocaml_lex_comment_rec c lexbuf 77
            and __ocaml_lex_comment_rec c lexbuf __ocaml_lex_state =
              match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf
              with
              | 0 -> (store c; with_curr_loc comment c; parse comment c)
              | 1 -> store c
              | 2 ->
                  (store c;
                   if quotations c then with_curr_loc quotation c else ();
                   parse comment c)
              | 3 -> store_parse comment c
              | 4 ->
                  (store c;
                   (try with_curr_loc string c
                    with
                    | Loc.Exc_located (_, (Error.E Unterminated_string)) ->
                        err Unterminated_string_in_comment (loc c));
                   Buffer.add_char c.buffer '"';
                   parse comment c)
              | 5 -> store_parse comment c
              | 6 -> store_parse comment c
              | 7 -> (update_loc c None 1 false 1; store_parse comment c)
              | 8 -> store_parse comment c
              | 9 -> store_parse comment c
              | 10 -> store_parse comment c
              | 11 -> store_parse comment c
              | 12 -> err Unterminated_comment (loc c)
              | 13 -> (update_loc c None 1 false 0; store_parse comment c)
              | 14 -> store_parse comment c
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_comment_rec c lexbuf __ocaml_lex_state)
            and string c lexbuf =
              (lexbuf.Lexing.lex_mem <- Array.create 2 (-1);
               __ocaml_lex_string_rec c lexbuf 104)
            and __ocaml_lex_string_rec c lexbuf __ocaml_lex_state =
              match Lexing.new_engine __ocaml_lex_tables __ocaml_lex_state
                      lexbuf
              with
              | 0 -> set_start_p c
              | 1 ->
                  let space =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_mem.(0)
                      lexbuf.Lexing.lex_curr_pos
                  in
                    (update_loc c None 1 false (String.length space);
                     store_parse string c)
              | 2 -> store_parse string c
              | 3 -> store_parse string c
              | 4 -> store_parse string c
              | 5 ->
                  let x =
                    Lexing.sub_lexeme_char lexbuf
                      (lexbuf.Lexing.lex_start_pos + 1)
                  in
                    if is_in_comment c
                    then store_parse string c
                    else
                      (warn (Illegal_escape (String.make 1 x))
                         (Loc.of_lexbuf lexbuf);
                       store_parse string c)
              | 6 -> (update_loc c None 1 false 0; store_parse string c)
              | 7 -> err Unterminated_string (loc c)
              | 8 -> store_parse string c
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_string_rec c lexbuf __ocaml_lex_state)
            and symbolchar_star beginning c lexbuf =
              __ocaml_lex_symbolchar_star_rec beginning c lexbuf 114
            and
              __ocaml_lex_symbolchar_star_rec beginning c lexbuf
                                              __ocaml_lex_state =
              match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf
              with
              | 0 ->
                  let tok =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in
                    (move_start_p (-String.length beginning) c;
                     SYMBOL (beginning ^ tok))
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_symbolchar_star_rec beginning c lexbuf
                     __ocaml_lex_state)
            and maybe_quotation_at c lexbuf =
              __ocaml_lex_maybe_quotation_at_rec c lexbuf 115
            and
              __ocaml_lex_maybe_quotation_at_rec c lexbuf __ocaml_lex_state =
              match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf
              with
              | 0 ->
                  let loc =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    mk_quotation quotation c "" loc (3 + (String.length loc))
              | 1 ->
                  let tok =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in SYMBOL ("<@" ^ tok)
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_maybe_quotation_at_rec c lexbuf
                     __ocaml_lex_state)
            and maybe_quotation_colon c lexbuf =
              (lexbuf.Lexing.lex_mem <- Array.create 2 (-1);
               __ocaml_lex_maybe_quotation_colon_rec c lexbuf 118)
            and
              __ocaml_lex_maybe_quotation_colon_rec c lexbuf
                                                    __ocaml_lex_state =
              match Lexing.new_engine __ocaml_lex_tables __ocaml_lex_state
                      lexbuf
              with
              | 0 ->
                  let name =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    mk_quotation quotation c name ""
                      (3 + (String.length name))
              | 1 ->
                  let name =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_mem.(0)
                  and loc =
                    Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_mem.(0) + 1)
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    mk_quotation quotation c name loc
                      ((4 + (String.length loc)) + (String.length name))
              | 2 ->
                  let tok =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      lexbuf.Lexing.lex_curr_pos
                  in SYMBOL ("<:" ^ tok)
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_maybe_quotation_colon_rec c lexbuf
                     __ocaml_lex_state)
            and quotation c lexbuf = __ocaml_lex_quotation_rec c lexbuf 124
            and __ocaml_lex_quotation_rec c lexbuf __ocaml_lex_state =
              match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf
              with
              | 0 -> (store c; with_curr_loc quotation c; parse quotation c)
              | 1 -> store c
              | 2 -> err Unterminated_quotation (loc c)
              | 3 -> (update_loc c None 1 false 0; store_parse quotation c)
              | 4 -> store_parse quotation c
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_quotation_rec c lexbuf __ocaml_lex_state)
            and dollar c lexbuf = __ocaml_lex_dollar_rec c lexbuf 132
            and __ocaml_lex_dollar_rec c lexbuf __ocaml_lex_state =
              match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf
              with
              | 0 -> (set_start_p c; ANTIQUOT ("", ""))
              | 1 ->
                  let name =
                    Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos
                      (lexbuf.Lexing.lex_curr_pos + (-1))
                  in
                    with_curr_loc (antiquot name)
                      (shift (1 + (String.length name)) c)
              | 2 -> store_parse (antiquot "") c
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_dollar_rec c lexbuf __ocaml_lex_state)
            and antiquot name c lexbuf =
              __ocaml_lex_antiquot_rec name c lexbuf 138
            and __ocaml_lex_antiquot_rec name c lexbuf __ocaml_lex_state =
              match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf
              with
              | 0 -> (set_start_p c; ANTIQUOT (name, buff_contents c))
              | 1 -> err Unterminated_antiquot (loc c)
              | 2 ->
                  (update_loc c None 1 false 0;
                   store_parse (antiquot name) c)
              | 3 ->
                  (store c;
                   with_curr_loc quotation c;
                   parse (antiquot name) c)
              | 4 -> store_parse (antiquot name) c
              | __ocaml_lex_state ->
                  (lexbuf.Lexing.refill_buff lexbuf;
                   __ocaml_lex_antiquot_rec name c lexbuf __ocaml_lex_state)
            let lexing_store s buff max =
              let rec self n s =
                if n >= max
                then n
                else
                  (match Stream.peek s with
                   | Some x -> (Stream.junk s; buff.[n] <- x; succ n)
                   | _ -> n)
              in self 0 s
            let from_context c =
              let next _ =
                let tok = with_curr_loc token c in
                let loc = Loc.of_lexbuf c.lexbuf in Some (tok, loc)
              in Stream.from next
            let from_lexbuf ?(quotations = true) lb =
              let c =
                {
                  (default_context lb)
                  with
                  
                  loc = Loc.of_lexbuf lb;
                  quotations = quotations;
                }
              in from_context c
            let setup_loc lb loc =
              let start_pos = Loc.start_pos loc
              in
                (lb.lex_abs_pos <- start_pos.pos_cnum;
                 lb.lex_curr_p <- start_pos)
            let from_string ?quotations loc str =
              let lb = Lexing.from_string str
              in (setup_loc lb loc; from_lexbuf ?quotations lb)
            let from_stream ?quotations loc strm =
              let lb = Lexing.from_function (lexing_store strm)
              in (setup_loc lb loc; from_lexbuf ?quotations lb)
            let mk () loc strm =
              from_stream ~quotations: !Camlp4_config.quotations loc strm
          end
      end
    module Camlp4Ast =
      struct
        module Make (Loc : Sig.Loc) : Sig.Camlp4Ast with module Loc = Loc =
          struct
            module Loc = Loc
            module Ast =
              struct
                include Sig.MakeCamlp4Ast(Loc)
                let safe_string_escaped s =
                  if
                    ((String.length s) > 2) &&
                      ((s.[0] = '\\') && (s.[1] = '$'))
                  then s
                  else String.escaped s
              end
            include Ast
            external loc_of_ctyp : ctyp -> Loc.t = "%field0"
            external loc_of_patt : patt -> Loc.t = "%field0"
            external loc_of_expr : expr -> Loc.t = "%field0"
            external loc_of_module_type : module_type -> Loc.t = "%field0"
            external loc_of_module_expr : module_expr -> Loc.t = "%field0"
            external loc_of_sig_item : sig_item -> Loc.t = "%field0"
            external loc_of_str_item : str_item -> Loc.t = "%field0"
            external loc_of_class_type : class_type -> Loc.t = "%field0"
            external loc_of_class_sig_item : class_sig_item -> Loc.t =
              "%field0"
            external loc_of_class_expr : class_expr -> Loc.t = "%field0"
            external loc_of_class_str_item : class_str_item -> Loc.t =
              "%field0"
            external loc_of_with_constr : with_constr -> Loc.t = "%field0"
            external loc_of_binding : binding -> Loc.t = "%field0"
            external loc_of_module_binding : module_binding -> Loc.t =
              "%field0"
            external loc_of_match_case : match_case -> Loc.t = "%field0"
            external loc_of_ident : ident -> Loc.t = "%field0"
            module Meta =
              struct
                module type META_LOC =
                  sig
                    val meta_loc_patt : Loc.t -> Loc.t -> Ast.patt
                    val meta_loc_expr : Loc.t -> Loc.t -> Ast.expr
                  end
                module MetaLoc =
                  struct
                    let meta_loc_patt _loc location =
                      let (a, b, c, d, e, f, g, h) = Loc.to_tuple location
                      in
                        Ast.PaApp (_loc,
                          Ast.PaId (_loc,
                            Ast.IdAcc (_loc, Ast.IdUid (_loc, "Loc"),
                              Ast.IdLid (_loc, "of_tuple"))),
                          Ast.PaTup (_loc,
                            Ast.PaCom (_loc,
                              Ast.PaStr (_loc, Ast.safe_string_escaped a),
                              Ast.PaCom (_loc,
                                Ast.PaCom (_loc,
                                  Ast.PaCom (_loc,
                                    Ast.PaCom (_loc,
                                      Ast.PaCom (_loc,
                                        Ast.PaCom (_loc,
                                          Ast.PaInt (_loc, string_of_int b),
                                          Ast.PaInt (_loc, string_of_int c)),
                                        Ast.PaInt (_loc, string_of_int d)),
                                      Ast.PaInt (_loc, string_of_int e)),
                                    Ast.PaInt (_loc, string_of_int f)),
                                  Ast.PaInt (_loc, string_of_int g)),
                                if h
                                then
                                  Ast.PaId (_loc, Ast.IdUid (_loc, "True"))
                                else
                                  Ast.PaId (_loc, Ast.IdUid (_loc, "False"))))))
                    let meta_loc_expr _loc location =
                      let (a, b, c, d, e, f, g, h) = Loc.to_tuple location
                      in
                        Ast.ExApp (_loc,
                          Ast.ExId (_loc,
                            Ast.IdAcc (_loc, Ast.IdUid (_loc, "Loc"),
                              Ast.IdLid (_loc, "of_tuple"))),
                          Ast.ExTup (_loc,
                            Ast.ExCom (_loc,
                              Ast.ExStr (_loc, Ast.safe_string_escaped a),
                              Ast.ExCom (_loc,
                                Ast.ExCom (_loc,
                                  Ast.ExCom (_loc,
                                    Ast.ExCom (_loc,
                                      Ast.ExCom (_loc,
                                        Ast.ExCom (_loc,
                                          Ast.ExInt (_loc, string_of_int b),
                                          Ast.ExInt (_loc, string_of_int c)),
                                        Ast.ExInt (_loc, string_of_int d)),
                                      Ast.ExInt (_loc, string_of_int e)),
                                    Ast.ExInt (_loc, string_of_int f)),
                                  Ast.ExInt (_loc, string_of_int g)),
                                if h
                                then
                                  Ast.ExId (_loc, Ast.IdUid (_loc, "True"))
                                else
                                  Ast.ExId (_loc, Ast.IdUid (_loc, "False"))))))
                  end
                module MetaGhostLoc =
                  struct
                    let meta_loc_patt _loc _ =
                      Ast.PaId (_loc,
                        Ast.IdAcc (_loc, Ast.IdUid (_loc, "Loc"),
                          Ast.IdLid (_loc, "ghost")))
                    let meta_loc_expr _loc _ =
                      Ast.ExId (_loc,
                        Ast.IdAcc (_loc, Ast.IdUid (_loc, "Loc"),
                          Ast.IdLid (_loc, "ghost")))
                  end
                module MetaLocVar =
                  struct
                    let meta_loc_patt _loc _ =
                      Ast.PaId (_loc, Ast.IdLid (_loc, !Loc.name))
                    let meta_loc_expr _loc _ =
                      Ast.ExId (_loc, Ast.IdLid (_loc, !Loc.name))
                  end
                module Make (MetaLoc : META_LOC) =
                  struct
                    open MetaLoc
                    let meta_acc_Loc_t = meta_loc_expr
                    module Expr =
                      struct
                        let meta_string _loc s = Ast.ExStr (_loc, s)
                        let meta_int _loc s = Ast.ExInt (_loc, s)
                        let meta_float _loc s = Ast.ExFlo (_loc, s)
                        let meta_char _loc s = Ast.ExChr (_loc, s)
                        let meta_bool _loc =
                          function
                          | false ->
                              Ast.ExId (_loc, Ast.IdUid (_loc, "False"))
                          | true -> Ast.ExId (_loc, Ast.IdUid (_loc, "True"))
                        let rec meta_list mf_a _loc =
                          function
                          | [] -> Ast.ExId (_loc, Ast.IdUid (_loc, "[]"))
                          | x :: xs ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc, Ast.IdUid (_loc, "::")),
                                  mf_a _loc x),
                                meta_list mf_a _loc xs)
                        let rec meta_binding _loc =
                          function
                          | Ast.BiAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.BiEq (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "BiEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_expr _loc x2)
                          | Ast.BiSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "BiSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_binding _loc x1),
                                meta_binding _loc x2)
                          | Ast.BiAnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "BiAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_binding _loc x1),
                                meta_binding _loc x2)
                          | Ast.BiNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "BiNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_expr _loc =
                          function
                          | Ast.CeAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.CeEq (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_class_expr _loc x2)
                          | Ast.CeAnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_class_expr _loc x2)
                          | Ast.CeTyc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CeStr (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeStr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_class_str_item _loc x2)
                          | Ast.CeLet (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CeLet"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_binding _loc x2),
                                meta_class_expr _loc x3)
                          | Ast.CeFun (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeFun"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_class_expr _loc x2)
                          | Ast.CeCon (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CeCon"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_ident _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CeApp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.CeNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CeNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_sig_item _loc =
                          function
                          | Ast.CgAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.CgVir (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CgVir"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CgVal (x0, x1, x2, x3, x4) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExApp (_loc,
                                        Ast.ExId (_loc,
                                          Ast.IdAcc (_loc,
                                            Ast.IdUid (_loc, "Ast"),
                                            Ast.IdUid (_loc, "CgVal"))),
                                        meta_acc_Loc_t _loc x0),
                                      meta_string _loc x1),
                                    meta_meta_bool _loc x2),
                                  meta_meta_bool _loc x3),
                                meta_ctyp _loc x4)
                          | Ast.CgMth (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CgMth"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CgInh (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "CgInh"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.CgSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CgSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_sig_item _loc x1),
                                meta_class_sig_item _loc x2)
                          | Ast.CgCtr (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CgCtr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.CgNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CgNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_str_item _loc =
                          function
                          | Ast.CrAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.CrVvr (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CrVvr"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CrVir (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CrVir"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CrVal (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CrVal"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_expr _loc x3)
                          | Ast.CrMth (x0, x1, x2, x3, x4) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExApp (_loc,
                                        Ast.ExId (_loc,
                                          Ast.IdAcc (_loc,
                                            Ast.IdUid (_loc, "Ast"),
                                            Ast.IdUid (_loc, "CrMth"))),
                                        meta_acc_Loc_t _loc x0),
                                      meta_string _loc x1),
                                    meta_meta_bool _loc x2),
                                  meta_expr _loc x3),
                                meta_ctyp _loc x4)
                          | Ast.CrIni (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "CrIni"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.CrInh (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CrInh"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_string _loc x2)
                          | Ast.CrCtr (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CrCtr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.CrSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CrSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_str_item _loc x1),
                                meta_class_str_item _loc x2)
                          | Ast.CrNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CrNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_type _loc =
                          function
                          | Ast.CtAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.CtEq (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_type _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtCol (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtCol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_type _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtAnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_type _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtSig (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtSig"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_class_sig_item _loc x2)
                          | Ast.CtFun (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtFun"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtCon (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CtCon"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_ident _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CtNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CtNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_ctyp _loc =
                          function
                          | Ast.TyAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.TyOfAmp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOfAmp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyAmp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyAmp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyVrnInfSup (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyVrnInfSup"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyVrnInf (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrnInf"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyVrnSup (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrnSup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyVrnEq (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrnEq"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TySta (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TySta"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyTup (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyTup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyMut (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyMut"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyPrv (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyPrv"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyOr (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyAnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyOf (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOf"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TySum (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TySum"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyCom (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyCom"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TySem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TySem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyCol (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyCol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyRec (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyRec"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyVrn (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyQuM (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyQuM"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyQuP (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyQuP"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyQuo (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyQuo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyPol (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyPol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyOlb (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOlb"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyObj (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyObj"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_meta_bool _loc x2)
                          | Ast.TyDcl (x0, x1, x2, x3, x4) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExApp (_loc,
                                        Ast.ExId (_loc,
                                          Ast.IdAcc (_loc,
                                            Ast.IdUid (_loc, "Ast"),
                                            Ast.IdUid (_loc, "TyDcl"))),
                                        meta_acc_Loc_t _loc x0),
                                      meta_string _loc x1),
                                    meta_list meta_ctyp _loc x2),
                                  meta_ctyp _loc x3),
                                meta_list
                                  (fun _loc (x1, x2) ->
                                     Ast.ExTup (_loc,
                                       Ast.ExCom (_loc, meta_ctyp _loc x1,
                                         meta_ctyp _loc x2)))
                                  _loc x4)
                          | Ast.TyMan (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyMan"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyId (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.TyLab (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyLab"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyCls (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyCls"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.TyArr (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyArr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyApp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyAny x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "TyAny"))),
                                meta_acc_Loc_t _loc x0)
                          | Ast.TyAli (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyAli"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "TyNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_expr _loc =
                          function
                          | Ast.ExWhi (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExWhi"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExVrn (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExVrn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExTyc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.ExCom (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExCom"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExTup (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExTup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExTry (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExTry"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_match_case _loc x2)
                          | Ast.ExStr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExStr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExSte (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExSte"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExSnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExSnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_string _loc x2)
                          | Ast.ExSeq (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExSeq"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExRec (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExRec"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_binding _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExOvr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExOvr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_binding _loc x1)
                          | Ast.ExOlb (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExOlb"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExObj (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExObj"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_class_str_item _loc x2)
                          | Ast.ExNew (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExNew"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.ExMat (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExMat"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_match_case _loc x2)
                          | Ast.ExLmd (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExLmd"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_expr _loc x2),
                                meta_expr _loc x3)
                          | Ast.ExLet (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExLet"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_binding _loc x2),
                                meta_expr _loc x3)
                          | Ast.ExLaz (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExLaz"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExLab (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExLab"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExNativeInt (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExNativeInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExInt64 (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExInt64"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExInt32 (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExInt32"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExInt (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExIfe (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExIfe"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_expr _loc x1),
                                  meta_expr _loc x2),
                                meta_expr _loc x3)
                          | Ast.ExFun (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExFun"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_match_case _loc x1)
                          | Ast.ExFor (x0, x1, x2, x3, x4, x5) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExApp (_loc,
                                        Ast.ExApp (_loc,
                                          Ast.ExId (_loc,
                                            Ast.IdAcc (_loc,
                                              Ast.IdUid (_loc, "Ast"),
                                              Ast.IdUid (_loc, "ExFor"))),
                                          meta_acc_Loc_t _loc x0),
                                        meta_string _loc x1),
                                      meta_expr _loc x2),
                                    meta_expr _loc x3),
                                  meta_meta_bool _loc x4),
                                meta_expr _loc x5)
                          | Ast.ExFlo (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExFlo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExCoe (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExCoe"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_expr _loc x1),
                                  meta_ctyp _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.ExChr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExChr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExAss (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExAss"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExAsr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExAsr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExAsf x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "ExAsf"))),
                                meta_acc_Loc_t _loc x0)
                          | Ast.ExSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExArr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExArr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExAre (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExAre"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExApp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.ExAcc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExAcc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExId (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.ExNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "ExNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_ident _loc =
                          function
                          | Ast.IdAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.IdUid (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "IdUid"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.IdLid (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "IdLid"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.IdApp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "IdApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ident _loc x1),
                                meta_ident _loc x2)
                          | Ast.IdAcc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "IdAcc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ident _loc x1),
                                meta_ident _loc x2)
                        and meta_match_case _loc =
                          function
                          | Ast.McAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.McArr (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "McArr"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_patt _loc x1),
                                  meta_expr _loc x2),
                                meta_expr _loc x3)
                          | Ast.McOr (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "McOr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_match_case _loc x1),
                                meta_match_case _loc x2)
                          | Ast.McNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "McNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_meta_bool _loc =
                          function
                          | Ast.BAnt x0 -> Ast.ExAnt (_loc, x0)
                          | Ast.BFalse ->
                              Ast.ExId (_loc,
                                Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                  Ast.IdUid (_loc, "BFalse")))
                          | Ast.BTrue ->
                              Ast.ExId (_loc,
                                Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                  Ast.IdUid (_loc, "BTrue")))
                        and meta_meta_option mf_a _loc =
                          function
                          | Ast.OAnt x0 -> Ast.ExAnt (_loc, x0)
                          | Ast.OSome x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "OSome"))),
                                mf_a _loc x0)
                          | Ast.ONone ->
                              Ast.ExId (_loc,
                                Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                  Ast.IdUid (_loc, "ONone")))
                        and meta_module_binding _loc =
                          function
                          | Ast.MbAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.MbCol (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MbCol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.MbColEq (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "MbColEq"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_type _loc x2),
                                meta_module_expr _loc x3)
                          | Ast.MbAnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MbAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_binding _loc x1),
                                meta_module_binding _loc x2)
                          | Ast.MbNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "MbNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_module_expr _loc =
                          function
                          | Ast.MeAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.MeTyc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MeTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_expr _loc x1),
                                meta_module_type _loc x2)
                          | Ast.MeStr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MeStr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_str_item _loc x1)
                          | Ast.MeFun (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "MeFun"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_type _loc x2),
                                meta_module_expr _loc x3)
                          | Ast.MeApp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MeApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_expr _loc x1),
                                meta_module_expr _loc x2)
                          | Ast.MeId (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MeId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                        and meta_module_type _loc =
                          function
                          | Ast.MtAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.MtWit (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MtWit"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_type _loc x1),
                                meta_with_constr _loc x2)
                          | Ast.MtSig (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MtSig"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_sig_item _loc x1)
                          | Ast.MtQuo (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MtQuo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.MtFun (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "MtFun"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_type _loc x2),
                                meta_module_type _loc x3)
                          | Ast.MtId (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MtId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                        and meta_patt _loc =
                          function
                          | Ast.PaVrn (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaVrn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaTyp (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaTyp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.PaTyc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.PaTup (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaTup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_patt _loc x1)
                          | Ast.PaStr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaStr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaEq (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaRec (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaRec"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_patt _loc x1)
                          | Ast.PaRng (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaRng"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaOrp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaOrp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaOlbi (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "PaOlbi"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_patt _loc x2),
                                meta_expr _loc x3)
                          | Ast.PaOlb (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaOlb"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaLab (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaLab"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaFlo (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaFlo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaNativeInt (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaNativeInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaInt64 (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaInt64"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaInt32 (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaInt32"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaInt (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaChr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaChr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaCom (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaCom"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaArr (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaArr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_patt _loc x1)
                          | Ast.PaApp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaAny x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "PaAny"))),
                                meta_acc_Loc_t _loc x0)
                          | Ast.PaAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.PaAli (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaAli"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaId (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.PaNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "PaNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_sig_item _loc =
                          function
                          | Ast.SgAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.SgVal (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgVal"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.SgTyp (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgTyp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.SgOpn (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgOpn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.SgMty (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgMty"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.SgRecMod (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgRecMod"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_binding _loc x1)
                          | Ast.SgMod (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgMod"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.SgInc (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgInc"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_type _loc x1)
                          | Ast.SgExt (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "SgExt"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_ctyp _loc x2),
                                meta_string _loc x3)
                          | Ast.SgExc (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgExc"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.SgDir (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgDir"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.SgSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_sig_item _loc x1),
                                meta_sig_item _loc x2)
                          | Ast.SgClt (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgClt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.SgCls (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgCls"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.SgNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "SgNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_str_item _loc =
                          function
                          | Ast.StAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.StVal (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StVal"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_meta_bool _loc x1),
                                meta_binding _loc x2)
                          | Ast.StTyp (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StTyp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.StOpn (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StOpn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.StMty (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StMty"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.StRecMod (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StRecMod"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_binding _loc x1)
                          | Ast.StMod (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StMod"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_expr _loc x2)
                          | Ast.StInc (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StInc"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_expr _loc x1)
                          | Ast.StExt (x0, x1, x2, x3) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExApp (_loc,
                                      Ast.ExId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "StExt"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_ctyp _loc x2),
                                meta_string _loc x3)
                          | Ast.StExp (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StExp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.StExc (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StExc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_meta_option meta_ident _loc x2)
                          | Ast.StDir (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StDir"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.StSem (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_str_item _loc x1),
                                meta_str_item _loc x2)
                          | Ast.StClt (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StClt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.StCls (x0, x1) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StCls"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_expr _loc x1)
                          | Ast.StNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "StNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_with_constr _loc =
                          function
                          | Ast.WcAnt (x0, x1) -> Ast.ExAnt (x0, x1)
                          | Ast.WcAnd (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "WcAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_with_constr _loc x1),
                                meta_with_constr _loc x2)
                          | Ast.WcMod (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "WcMod"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ident _loc x1),
                                meta_ident _loc x2)
                          | Ast.WcTyp (x0, x1, x2) ->
                              Ast.ExApp (_loc,
                                Ast.ExApp (_loc,
                                  Ast.ExApp (_loc,
                                    Ast.ExId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "WcTyp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.WcNil x0 ->
                              Ast.ExApp (_loc,
                                Ast.ExId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "WcNil"))),
                                meta_acc_Loc_t _loc x0)
                      end
                    let meta_acc_Loc_t = meta_loc_patt
                    module Patt =
                      struct
                        let meta_string _loc s = Ast.PaStr (_loc, s)
                        let meta_int _loc s = Ast.PaInt (_loc, s)
                        let meta_float _loc s = Ast.PaFlo (_loc, s)
                        let meta_char _loc s = Ast.PaChr (_loc, s)
                        let meta_bool _loc =
                          function
                          | false ->
                              Ast.PaId (_loc, Ast.IdUid (_loc, "False"))
                          | true -> Ast.PaId (_loc, Ast.IdUid (_loc, "True"))
                        let rec meta_list mf_a _loc =
                          function
                          | [] -> Ast.PaId (_loc, Ast.IdUid (_loc, "[]"))
                          | x :: xs ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc, Ast.IdUid (_loc, "::")),
                                  mf_a _loc x),
                                meta_list mf_a _loc xs)
                        let rec meta_binding _loc =
                          function
                          | Ast.BiAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.BiEq (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "BiEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_expr _loc x2)
                          | Ast.BiSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "BiSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_binding _loc x1),
                                meta_binding _loc x2)
                          | Ast.BiAnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "BiAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_binding _loc x1),
                                meta_binding _loc x2)
                          | Ast.BiNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "BiNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_expr _loc =
                          function
                          | Ast.CeAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.CeEq (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_class_expr _loc x2)
                          | Ast.CeAnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_class_expr _loc x2)
                          | Ast.CeTyc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CeStr (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeStr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_class_str_item _loc x2)
                          | Ast.CeLet (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CeLet"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_binding _loc x2),
                                meta_class_expr _loc x3)
                          | Ast.CeFun (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeFun"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_class_expr _loc x2)
                          | Ast.CeCon (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CeCon"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_ident _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CeApp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CeApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.CeNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CeNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_sig_item _loc =
                          function
                          | Ast.CgAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.CgVir (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CgVir"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CgVal (x0, x1, x2, x3, x4) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaApp (_loc,
                                        Ast.PaId (_loc,
                                          Ast.IdAcc (_loc,
                                            Ast.IdUid (_loc, "Ast"),
                                            Ast.IdUid (_loc, "CgVal"))),
                                        meta_acc_Loc_t _loc x0),
                                      meta_string _loc x1),
                                    meta_meta_bool _loc x2),
                                  meta_meta_bool _loc x3),
                                meta_ctyp _loc x4)
                          | Ast.CgMth (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CgMth"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CgInh (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "CgInh"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.CgSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CgSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_sig_item _loc x1),
                                meta_class_sig_item _loc x2)
                          | Ast.CgCtr (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CgCtr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.CgNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CgNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_str_item _loc =
                          function
                          | Ast.CrAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.CrVvr (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CrVvr"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CrVir (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CrVir"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CrVal (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CrVal"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_meta_bool _loc x2),
                                meta_expr _loc x3)
                          | Ast.CrMth (x0, x1, x2, x3, x4) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaApp (_loc,
                                        Ast.PaId (_loc,
                                          Ast.IdAcc (_loc,
                                            Ast.IdUid (_loc, "Ast"),
                                            Ast.IdUid (_loc, "CrMth"))),
                                        meta_acc_Loc_t _loc x0),
                                      meta_string _loc x1),
                                    meta_meta_bool _loc x2),
                                  meta_expr _loc x3),
                                meta_ctyp _loc x4)
                          | Ast.CrIni (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "CrIni"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.CrInh (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CrInh"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_expr _loc x1),
                                meta_string _loc x2)
                          | Ast.CrCtr (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CrCtr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.CrSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CrSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_str_item _loc x1),
                                meta_class_str_item _loc x2)
                          | Ast.CrNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CrNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_class_type _loc =
                          function
                          | Ast.CtAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.CtEq (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_type _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtCol (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtCol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_type _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtAnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_class_type _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtSig (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtSig"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_class_sig_item _loc x2)
                          | Ast.CtFun (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "CtFun"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_class_type _loc x2)
                          | Ast.CtCon (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "CtCon"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_ident _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.CtNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "CtNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_ctyp _loc =
                          function
                          | Ast.TyAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.TyOfAmp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOfAmp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyAmp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyAmp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyVrnInfSup (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyVrnInfSup"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyVrnInf (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrnInf"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyVrnSup (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrnSup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyVrnEq (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrnEq"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TySta (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TySta"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyTup (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyTup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyMut (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyMut"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyPrv (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyPrv"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyOr (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyAnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyOf (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOf"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TySum (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TySum"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyCom (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyCom"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TySem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TySem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyCol (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyCol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyRec (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyRec"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.TyVrn (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyVrn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyQuM (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyQuM"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyQuP (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyQuP"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyQuo (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyQuo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.TyPol (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyPol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyOlb (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyOlb"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyObj (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyObj"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_meta_bool _loc x2)
                          | Ast.TyDcl (x0, x1, x2, x3, x4) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaApp (_loc,
                                        Ast.PaId (_loc,
                                          Ast.IdAcc (_loc,
                                            Ast.IdUid (_loc, "Ast"),
                                            Ast.IdUid (_loc, "TyDcl"))),
                                        meta_acc_Loc_t _loc x0),
                                      meta_string _loc x1),
                                    meta_list meta_ctyp _loc x2),
                                  meta_ctyp _loc x3),
                                meta_list
                                  (fun _loc (x1, x2) ->
                                     Ast.PaTup (_loc,
                                       Ast.PaCom (_loc, meta_ctyp _loc x1,
                                         meta_ctyp _loc x2)))
                                  _loc x4)
                          | Ast.TyMan (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyMan"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyId (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.TyLab (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyLab"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyCls (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "TyCls"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.TyArr (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyArr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyApp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyAny x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "TyAny"))),
                                meta_acc_Loc_t _loc x0)
                          | Ast.TyAli (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "TyAli"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.TyNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "TyNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_expr _loc =
                          function
                          | Ast.ExWhi (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExWhi"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExVrn (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExVrn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExTyc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.ExCom (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExCom"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExTup (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExTup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExTry (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExTry"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_match_case _loc x2)
                          | Ast.ExStr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExStr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExSte (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExSte"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExSnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExSnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_string _loc x2)
                          | Ast.ExSeq (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExSeq"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExRec (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExRec"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_binding _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExOvr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExOvr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_binding _loc x1)
                          | Ast.ExOlb (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExOlb"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExObj (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExObj"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_class_str_item _loc x2)
                          | Ast.ExNew (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExNew"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.ExMat (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExMat"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_match_case _loc x2)
                          | Ast.ExLmd (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExLmd"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_expr _loc x2),
                                meta_expr _loc x3)
                          | Ast.ExLet (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExLet"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_meta_bool _loc x1),
                                  meta_binding _loc x2),
                                meta_expr _loc x3)
                          | Ast.ExLaz (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExLaz"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExLab (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExLab"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExNativeInt (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExNativeInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExInt64 (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExInt64"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExInt32 (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExInt32"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExInt (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExIfe (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExIfe"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_expr _loc x1),
                                  meta_expr _loc x2),
                                meta_expr _loc x3)
                          | Ast.ExFun (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExFun"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_match_case _loc x1)
                          | Ast.ExFor (x0, x1, x2, x3, x4, x5) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaApp (_loc,
                                        Ast.PaApp (_loc,
                                          Ast.PaId (_loc,
                                            Ast.IdAcc (_loc,
                                              Ast.IdUid (_loc, "Ast"),
                                              Ast.IdUid (_loc, "ExFor"))),
                                          meta_acc_Loc_t _loc x0),
                                        meta_string _loc x1),
                                      meta_expr _loc x2),
                                    meta_expr _loc x3),
                                  meta_meta_bool _loc x4),
                                meta_expr _loc x5)
                          | Ast.ExFlo (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExFlo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExCoe (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "ExCoe"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_expr _loc x1),
                                  meta_ctyp _loc x2),
                                meta_ctyp _loc x3)
                          | Ast.ExChr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExChr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.ExAss (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExAss"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExAsr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExAsr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExAsf x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "ExAsf"))),
                                meta_acc_Loc_t _loc x0)
                          | Ast.ExSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExArr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExArr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.ExAre (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExAre"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExApp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.ExAcc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "ExAcc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_expr _loc x1),
                                meta_expr _loc x2)
                          | Ast.ExId (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "ExId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.ExNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "ExNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_ident _loc =
                          function
                          | Ast.IdAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.IdUid (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "IdUid"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.IdLid (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "IdLid"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.IdApp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "IdApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ident _loc x1),
                                meta_ident _loc x2)
                          | Ast.IdAcc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "IdAcc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ident _loc x1),
                                meta_ident _loc x2)
                        and meta_match_case _loc =
                          function
                          | Ast.McAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.McArr (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "McArr"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_patt _loc x1),
                                  meta_expr _loc x2),
                                meta_expr _loc x3)
                          | Ast.McOr (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "McOr"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_match_case _loc x1),
                                meta_match_case _loc x2)
                          | Ast.McNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "McNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_meta_bool _loc =
                          function
                          | Ast.BAnt x0 -> Ast.PaAnt (_loc, x0)
                          | Ast.BFalse ->
                              Ast.PaId (_loc,
                                Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                  Ast.IdUid (_loc, "BFalse")))
                          | Ast.BTrue ->
                              Ast.PaId (_loc,
                                Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                  Ast.IdUid (_loc, "BTrue")))
                        and meta_meta_option mf_a _loc =
                          function
                          | Ast.OAnt x0 -> Ast.PaAnt (_loc, x0)
                          | Ast.OSome x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "OSome"))),
                                mf_a _loc x0)
                          | Ast.ONone ->
                              Ast.PaId (_loc,
                                Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                  Ast.IdUid (_loc, "ONone")))
                        and meta_module_binding _loc =
                          function
                          | Ast.MbAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.MbCol (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MbCol"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.MbColEq (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "MbColEq"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_type _loc x2),
                                meta_module_expr _loc x3)
                          | Ast.MbAnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MbAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_binding _loc x1),
                                meta_module_binding _loc x2)
                          | Ast.MbNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "MbNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_module_expr _loc =
                          function
                          | Ast.MeAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.MeTyc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MeTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_expr _loc x1),
                                meta_module_type _loc x2)
                          | Ast.MeStr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MeStr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_str_item _loc x1)
                          | Ast.MeFun (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "MeFun"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_type _loc x2),
                                meta_module_expr _loc x3)
                          | Ast.MeApp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MeApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_expr _loc x1),
                                meta_module_expr _loc x2)
                          | Ast.MeId (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MeId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                        and meta_module_type _loc =
                          function
                          | Ast.MtAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.MtWit (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "MtWit"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_module_type _loc x1),
                                meta_with_constr _loc x2)
                          | Ast.MtSig (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MtSig"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_sig_item _loc x1)
                          | Ast.MtQuo (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MtQuo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.MtFun (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "MtFun"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_module_type _loc x2),
                                meta_module_type _loc x3)
                          | Ast.MtId (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "MtId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                        and meta_patt _loc =
                          function
                          | Ast.PaVrn (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaVrn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaTyp (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaTyp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.PaTyc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaTyc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.PaTup (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaTup"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_patt _loc x1)
                          | Ast.PaStr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaStr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaEq (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaEq"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaRec (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaRec"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_patt _loc x1)
                          | Ast.PaRng (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaRng"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaOrp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaOrp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaOlbi (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "PaOlbi"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_patt _loc x2),
                                meta_expr _loc x3)
                          | Ast.PaOlb (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaOlb"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaLab (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaLab"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaFlo (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaFlo"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaNativeInt (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaNativeInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaInt64 (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaInt64"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaInt32 (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaInt32"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaInt (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaInt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaChr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaChr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_string _loc x1)
                          | Ast.PaSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaCom (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaCom"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaArr (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaArr"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_patt _loc x1)
                          | Ast.PaApp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaApp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaAny x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "PaAny"))),
                                meta_acc_Loc_t _loc x0)
                          | Ast.PaAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.PaAli (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "PaAli"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_patt _loc x1),
                                meta_patt _loc x2)
                          | Ast.PaId (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "PaId"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.PaNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "PaNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_sig_item _loc =
                          function
                          | Ast.SgAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.SgVal (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgVal"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.SgTyp (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgTyp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.SgOpn (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgOpn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.SgMty (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgMty"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.SgRecMod (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgRecMod"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_binding _loc x1)
                          | Ast.SgMod (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgMod"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.SgInc (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgInc"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_type _loc x1)
                          | Ast.SgExt (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "SgExt"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_ctyp _loc x2),
                                meta_string _loc x3)
                          | Ast.SgExc (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgExc"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.SgDir (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgDir"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.SgSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "SgSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_sig_item _loc x1),
                                meta_sig_item _loc x2)
                          | Ast.SgClt (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgClt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.SgCls (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "SgCls"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.SgNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "SgNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_str_item _loc =
                          function
                          | Ast.StAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.StVal (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StVal"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_meta_bool _loc x1),
                                meta_binding _loc x2)
                          | Ast.StTyp (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StTyp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ctyp _loc x1)
                          | Ast.StOpn (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StOpn"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_ident _loc x1)
                          | Ast.StMty (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StMty"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_type _loc x2)
                          | Ast.StRecMod (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StRecMod"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_binding _loc x1)
                          | Ast.StMod (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StMod"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_module_expr _loc x2)
                          | Ast.StInc (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StInc"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_module_expr _loc x1)
                          | Ast.StExt (x0, x1, x2, x3) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaApp (_loc,
                                      Ast.PaId (_loc,
                                        Ast.IdAcc (_loc,
                                          Ast.IdUid (_loc, "Ast"),
                                          Ast.IdUid (_loc, "StExt"))),
                                      meta_acc_Loc_t _loc x0),
                                    meta_string _loc x1),
                                  meta_ctyp _loc x2),
                                meta_string _loc x3)
                          | Ast.StExp (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StExp"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_expr _loc x1)
                          | Ast.StExc (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StExc"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_meta_option meta_ident _loc x2)
                          | Ast.StDir (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StDir"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_string _loc x1),
                                meta_expr _loc x2)
                          | Ast.StSem (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "StSem"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_str_item _loc x1),
                                meta_str_item _loc x2)
                          | Ast.StClt (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StClt"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_type _loc x1)
                          | Ast.StCls (x0, x1) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaId (_loc,
                                    Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                      Ast.IdUid (_loc, "StCls"))),
                                  meta_acc_Loc_t _loc x0),
                                meta_class_expr _loc x1)
                          | Ast.StNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "StNil"))),
                                meta_acc_Loc_t _loc x0)
                        and meta_with_constr _loc =
                          function
                          | Ast.WcAnt (x0, x1) -> Ast.PaAnt (x0, x1)
                          | Ast.WcAnd (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "WcAnd"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_with_constr _loc x1),
                                meta_with_constr _loc x2)
                          | Ast.WcMod (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "WcMod"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ident _loc x1),
                                meta_ident _loc x2)
                          | Ast.WcTyp (x0, x1, x2) ->
                              Ast.PaApp (_loc,
                                Ast.PaApp (_loc,
                                  Ast.PaApp (_loc,
                                    Ast.PaId (_loc,
                                      Ast.IdAcc (_loc,
                                        Ast.IdUid (_loc, "Ast"),
                                        Ast.IdUid (_loc, "WcTyp"))),
                                    meta_acc_Loc_t _loc x0),
                                  meta_ctyp _loc x1),
                                meta_ctyp _loc x2)
                          | Ast.WcNil x0 ->
                              Ast.PaApp (_loc,
                                Ast.PaId (_loc,
                                  Ast.IdAcc (_loc, Ast.IdUid (_loc, "Ast"),
                                    Ast.IdUid (_loc, "WcNil"))),
                                meta_acc_Loc_t _loc x0)
                      end
                  end
              end
            class map =
              object (o)
                method string = fun x -> (x : string)
                method int = fun x -> (x : int)
                method float = fun x -> (x : float)
                method bool = fun x -> (x : bool)
                method list : 'a 'b. ('a -> 'b) -> 'a list -> 'b list = List.
                  map
                method option : 'a 'b. ('a -> 'b) -> 'a option -> 'b option =
                  fun f -> function | None -> None | Some x -> Some (f x)
                method array : 'a 'b. ('a -> 'b) -> 'a array -> 'b array =
                  Array.map
                method ref : 'a 'b. ('a -> 'b) -> 'a ref -> 'b ref =
                  fun f { contents = x } -> {  contents = f x; }
                method _Loc_t : Loc.t -> Loc.t = fun x -> x
                method with_constr : with_constr -> with_constr =
                  function
                  | WcNil _x0 -> WcNil (o#_Loc_t _x0)
                  | WcTyp (_x0, _x1, _x2) ->
                      WcTyp (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | WcMod (_x0, _x1, _x2) ->
                      WcMod (o#_Loc_t _x0, o#ident _x1, o#ident _x2)
                  | WcAnd (_x0, _x1, _x2) ->
                      WcAnd (o#_Loc_t _x0, o#with_constr _x1,
                        o#with_constr _x2)
                  | WcAnt (_x0, _x1) -> WcAnt (o#_Loc_t _x0, o#string _x1)
                method str_item : str_item -> str_item =
                  function
                  | StNil _x0 -> StNil (o#_Loc_t _x0)
                  | StCls (_x0, _x1) ->
                      StCls (o#_Loc_t _x0, o#class_expr _x1)
                  | StClt (_x0, _x1) ->
                      StClt (o#_Loc_t _x0, o#class_type _x1)
                  | StSem (_x0, _x1, _x2) ->
                      StSem (o#_Loc_t _x0, o#str_item _x1, o#str_item _x2)
                  | StDir (_x0, _x1, _x2) ->
                      StDir (o#_Loc_t _x0, o#string _x1, o#expr _x2)
                  | StExc (_x0, _x1, _x2) ->
                      StExc (o#_Loc_t _x0, o#ctyp _x1,
                        o#meta_option o#ident _x2)
                  | StExp (_x0, _x1) -> StExp (o#_Loc_t _x0, o#expr _x1)
                  | StExt (_x0, _x1, _x2, _x3) ->
                      StExt (o#_Loc_t _x0, o#string _x1, o#ctyp _x2,
                        o#string _x3)
                  | StInc (_x0, _x1) ->
                      StInc (o#_Loc_t _x0, o#module_expr _x1)
                  | StMod (_x0, _x1, _x2) ->
                      StMod (o#_Loc_t _x0, o#string _x1, o#module_expr _x2)
                  | StRecMod (_x0, _x1) ->
                      StRecMod (o#_Loc_t _x0, o#module_binding _x1)
                  | StMty (_x0, _x1, _x2) ->
                      StMty (o#_Loc_t _x0, o#string _x1, o#module_type _x2)
                  | StOpn (_x0, _x1) -> StOpn (o#_Loc_t _x0, o#ident _x1)
                  | StTyp (_x0, _x1) -> StTyp (o#_Loc_t _x0, o#ctyp _x1)
                  | StVal (_x0, _x1, _x2) ->
                      StVal (o#_Loc_t _x0, o#meta_bool _x1, o#binding _x2)
                  | StAnt (_x0, _x1) -> StAnt (o#_Loc_t _x0, o#string _x1)
                method sig_item : sig_item -> sig_item =
                  function
                  | SgNil _x0 -> SgNil (o#_Loc_t _x0)
                  | SgCls (_x0, _x1) ->
                      SgCls (o#_Loc_t _x0, o#class_type _x1)
                  | SgClt (_x0, _x1) ->
                      SgClt (o#_Loc_t _x0, o#class_type _x1)
                  | SgSem (_x0, _x1, _x2) ->
                      SgSem (o#_Loc_t _x0, o#sig_item _x1, o#sig_item _x2)
                  | SgDir (_x0, _x1, _x2) ->
                      SgDir (o#_Loc_t _x0, o#string _x1, o#expr _x2)
                  | SgExc (_x0, _x1) -> SgExc (o#_Loc_t _x0, o#ctyp _x1)
                  | SgExt (_x0, _x1, _x2, _x3) ->
                      SgExt (o#_Loc_t _x0, o#string _x1, o#ctyp _x2,
                        o#string _x3)
                  | SgInc (_x0, _x1) ->
                      SgInc (o#_Loc_t _x0, o#module_type _x1)
                  | SgMod (_x0, _x1, _x2) ->
                      SgMod (o#_Loc_t _x0, o#string _x1, o#module_type _x2)
                  | SgRecMod (_x0, _x1) ->
                      SgRecMod (o#_Loc_t _x0, o#module_binding _x1)
                  | SgMty (_x0, _x1, _x2) ->
                      SgMty (o#_Loc_t _x0, o#string _x1, o#module_type _x2)
                  | SgOpn (_x0, _x1) -> SgOpn (o#_Loc_t _x0, o#ident _x1)
                  | SgTyp (_x0, _x1) -> SgTyp (o#_Loc_t _x0, o#ctyp _x1)
                  | SgVal (_x0, _x1, _x2) ->
                      SgVal (o#_Loc_t _x0, o#string _x1, o#ctyp _x2)
                  | SgAnt (_x0, _x1) -> SgAnt (o#_Loc_t _x0, o#string _x1)
                method patt : patt -> patt =
                  function
                  | PaNil _x0 -> PaNil (o#_Loc_t _x0)
                  | PaId (_x0, _x1) -> PaId (o#_Loc_t _x0, o#ident _x1)
                  | PaAli (_x0, _x1, _x2) ->
                      PaAli (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaAnt (_x0, _x1) -> PaAnt (o#_Loc_t _x0, o#string _x1)
                  | PaAny _x0 -> PaAny (o#_Loc_t _x0)
                  | PaApp (_x0, _x1, _x2) ->
                      PaApp (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaArr (_x0, _x1) -> PaArr (o#_Loc_t _x0, o#patt _x1)
                  | PaCom (_x0, _x1, _x2) ->
                      PaCom (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaSem (_x0, _x1, _x2) ->
                      PaSem (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaChr (_x0, _x1) -> PaChr (o#_Loc_t _x0, o#string _x1)
                  | PaInt (_x0, _x1) -> PaInt (o#_Loc_t _x0, o#string _x1)
                  | PaInt32 (_x0, _x1) ->
                      PaInt32 (o#_Loc_t _x0, o#string _x1)
                  | PaInt64 (_x0, _x1) ->
                      PaInt64 (o#_Loc_t _x0, o#string _x1)
                  | PaNativeInt (_x0, _x1) ->
                      PaNativeInt (o#_Loc_t _x0, o#string _x1)
                  | PaFlo (_x0, _x1) -> PaFlo (o#_Loc_t _x0, o#string _x1)
                  | PaLab (_x0, _x1, _x2) ->
                      PaLab (o#_Loc_t _x0, o#string _x1, o#patt _x2)
                  | PaOlb (_x0, _x1, _x2) ->
                      PaOlb (o#_Loc_t _x0, o#string _x1, o#patt _x2)
                  | PaOlbi (_x0, _x1, _x2, _x3) ->
                      PaOlbi (o#_Loc_t _x0, o#string _x1, o#patt _x2,
                        o#expr _x3)
                  | PaOrp (_x0, _x1, _x2) ->
                      PaOrp (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaRng (_x0, _x1, _x2) ->
                      PaRng (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaRec (_x0, _x1) -> PaRec (o#_Loc_t _x0, o#patt _x1)
                  | PaEq (_x0, _x1, _x2) ->
                      PaEq (o#_Loc_t _x0, o#patt _x1, o#patt _x2)
                  | PaStr (_x0, _x1) -> PaStr (o#_Loc_t _x0, o#string _x1)
                  | PaTup (_x0, _x1) -> PaTup (o#_Loc_t _x0, o#patt _x1)
                  | PaTyc (_x0, _x1, _x2) ->
                      PaTyc (o#_Loc_t _x0, o#patt _x1, o#ctyp _x2)
                  | PaTyp (_x0, _x1) -> PaTyp (o#_Loc_t _x0, o#ident _x1)
                  | PaVrn (_x0, _x1) -> PaVrn (o#_Loc_t _x0, o#string _x1)
                method module_type : module_type -> module_type =
                  function
                  | MtId (_x0, _x1) -> MtId (o#_Loc_t _x0, o#ident _x1)
                  | MtFun (_x0, _x1, _x2, _x3) ->
                      MtFun (o#_Loc_t _x0, o#string _x1, o#module_type _x2,
                        o#module_type _x3)
                  | MtQuo (_x0, _x1) -> MtQuo (o#_Loc_t _x0, o#string _x1)
                  | MtSig (_x0, _x1) -> MtSig (o#_Loc_t _x0, o#sig_item _x1)
                  | MtWit (_x0, _x1, _x2) ->
                      MtWit (o#_Loc_t _x0, o#module_type _x1,
                        o#with_constr _x2)
                  | MtAnt (_x0, _x1) -> MtAnt (o#_Loc_t _x0, o#string _x1)
                method module_expr : module_expr -> module_expr =
                  function
                  | MeId (_x0, _x1) -> MeId (o#_Loc_t _x0, o#ident _x1)
                  | MeApp (_x0, _x1, _x2) ->
                      MeApp (o#_Loc_t _x0, o#module_expr _x1,
                        o#module_expr _x2)
                  | MeFun (_x0, _x1, _x2, _x3) ->
                      MeFun (o#_Loc_t _x0, o#string _x1, o#module_type _x2,
                        o#module_expr _x3)
                  | MeStr (_x0, _x1) -> MeStr (o#_Loc_t _x0, o#str_item _x1)
                  | MeTyc (_x0, _x1, _x2) ->
                      MeTyc (o#_Loc_t _x0, o#module_expr _x1,
                        o#module_type _x2)
                  | MeAnt (_x0, _x1) -> MeAnt (o#_Loc_t _x0, o#string _x1)
                method module_binding : module_binding -> module_binding =
                  function
                  | MbNil _x0 -> MbNil (o#_Loc_t _x0)
                  | MbAnd (_x0, _x1, _x2) ->
                      MbAnd (o#_Loc_t _x0, o#module_binding _x1,
                        o#module_binding _x2)
                  | MbColEq (_x0, _x1, _x2, _x3) ->
                      MbColEq (o#_Loc_t _x0, o#string _x1, o#module_type _x2,
                        o#module_expr _x3)
                  | MbCol (_x0, _x1, _x2) ->
                      MbCol (o#_Loc_t _x0, o#string _x1, o#module_type _x2)
                  | MbAnt (_x0, _x1) -> MbAnt (o#_Loc_t _x0, o#string _x1)
                method meta_option :
                  'a 'b. ('a -> 'b) -> 'a meta_option -> 'b meta_option =
                  fun _f_a ->
                    function
                    | ONone -> ONone
                    | OSome _x0 -> OSome (_f_a _x0)
                    | OAnt _x0 -> OAnt (o#string _x0)
                method meta_bool : meta_bool -> meta_bool =
                  function
                  | BTrue -> BTrue
                  | BFalse -> BFalse
                  | BAnt _x0 -> BAnt (o#string _x0)
                method match_case : match_case -> match_case =
                  function
                  | McNil _x0 -> McNil (o#_Loc_t _x0)
                  | McOr (_x0, _x1, _x2) ->
                      McOr (o#_Loc_t _x0, o#match_case _x1, o#match_case _x2)
                  | McArr (_x0, _x1, _x2, _x3) ->
                      McArr (o#_Loc_t _x0, o#patt _x1, o#expr _x2,
                        o#expr _x3)
                  | McAnt (_x0, _x1) -> McAnt (o#_Loc_t _x0, o#string _x1)
                method ident : ident -> ident =
                  function
                  | IdAcc (_x0, _x1, _x2) ->
                      IdAcc (o#_Loc_t _x0, o#ident _x1, o#ident _x2)
                  | IdApp (_x0, _x1, _x2) ->
                      IdApp (o#_Loc_t _x0, o#ident _x1, o#ident _x2)
                  | IdLid (_x0, _x1) -> IdLid (o#_Loc_t _x0, o#string _x1)
                  | IdUid (_x0, _x1) -> IdUid (o#_Loc_t _x0, o#string _x1)
                  | IdAnt (_x0, _x1) -> IdAnt (o#_Loc_t _x0, o#string _x1)
                method expr : expr -> expr =
                  function
                  | ExNil _x0 -> ExNil (o#_Loc_t _x0)
                  | ExId (_x0, _x1) -> ExId (o#_Loc_t _x0, o#ident _x1)
                  | ExAcc (_x0, _x1, _x2) ->
                      ExAcc (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExAnt (_x0, _x1) -> ExAnt (o#_Loc_t _x0, o#string _x1)
                  | ExApp (_x0, _x1, _x2) ->
                      ExApp (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExAre (_x0, _x1, _x2) ->
                      ExAre (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExArr (_x0, _x1) -> ExArr (o#_Loc_t _x0, o#expr _x1)
                  | ExSem (_x0, _x1, _x2) ->
                      ExSem (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExAsf _x0 -> ExAsf (o#_Loc_t _x0)
                  | ExAsr (_x0, _x1) -> ExAsr (o#_Loc_t _x0, o#expr _x1)
                  | ExAss (_x0, _x1, _x2) ->
                      ExAss (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExChr (_x0, _x1) -> ExChr (o#_Loc_t _x0, o#string _x1)
                  | ExCoe (_x0, _x1, _x2, _x3) ->
                      ExCoe (o#_Loc_t _x0, o#expr _x1, o#ctyp _x2,
                        o#ctyp _x3)
                  | ExFlo (_x0, _x1) -> ExFlo (o#_Loc_t _x0, o#string _x1)
                  | ExFor (_x0, _x1, _x2, _x3, _x4, _x5) ->
                      ExFor (o#_Loc_t _x0, o#string _x1, o#expr _x2,
                        o#expr _x3, o#meta_bool _x4, o#expr _x5)
                  | ExFun (_x0, _x1) ->
                      ExFun (o#_Loc_t _x0, o#match_case _x1)
                  | ExIfe (_x0, _x1, _x2, _x3) ->
                      ExIfe (o#_Loc_t _x0, o#expr _x1, o#expr _x2,
                        o#expr _x3)
                  | ExInt (_x0, _x1) -> ExInt (o#_Loc_t _x0, o#string _x1)
                  | ExInt32 (_x0, _x1) ->
                      ExInt32 (o#_Loc_t _x0, o#string _x1)
                  | ExInt64 (_x0, _x1) ->
                      ExInt64 (o#_Loc_t _x0, o#string _x1)
                  | ExNativeInt (_x0, _x1) ->
                      ExNativeInt (o#_Loc_t _x0, o#string _x1)
                  | ExLab (_x0, _x1, _x2) ->
                      ExLab (o#_Loc_t _x0, o#string _x1, o#expr _x2)
                  | ExLaz (_x0, _x1) -> ExLaz (o#_Loc_t _x0, o#expr _x1)
                  | ExLet (_x0, _x1, _x2, _x3) ->
                      ExLet (o#_Loc_t _x0, o#meta_bool _x1, o#binding _x2,
                        o#expr _x3)
                  | ExLmd (_x0, _x1, _x2, _x3) ->
                      ExLmd (o#_Loc_t _x0, o#string _x1, o#module_expr _x2,
                        o#expr _x3)
                  | ExMat (_x0, _x1, _x2) ->
                      ExMat (o#_Loc_t _x0, o#expr _x1, o#match_case _x2)
                  | ExNew (_x0, _x1) -> ExNew (o#_Loc_t _x0, o#ident _x1)
                  | ExObj (_x0, _x1, _x2) ->
                      ExObj (o#_Loc_t _x0, o#patt _x1, o#class_str_item _x2)
                  | ExOlb (_x0, _x1, _x2) ->
                      ExOlb (o#_Loc_t _x0, o#string _x1, o#expr _x2)
                  | ExOvr (_x0, _x1) -> ExOvr (o#_Loc_t _x0, o#binding _x1)
                  | ExRec (_x0, _x1, _x2) ->
                      ExRec (o#_Loc_t _x0, o#binding _x1, o#expr _x2)
                  | ExSeq (_x0, _x1) -> ExSeq (o#_Loc_t _x0, o#expr _x1)
                  | ExSnd (_x0, _x1, _x2) ->
                      ExSnd (o#_Loc_t _x0, o#expr _x1, o#string _x2)
                  | ExSte (_x0, _x1, _x2) ->
                      ExSte (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExStr (_x0, _x1) -> ExStr (o#_Loc_t _x0, o#string _x1)
                  | ExTry (_x0, _x1, _x2) ->
                      ExTry (o#_Loc_t _x0, o#expr _x1, o#match_case _x2)
                  | ExTup (_x0, _x1) -> ExTup (o#_Loc_t _x0, o#expr _x1)
                  | ExCom (_x0, _x1, _x2) ->
                      ExCom (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                  | ExTyc (_x0, _x1, _x2) ->
                      ExTyc (o#_Loc_t _x0, o#expr _x1, o#ctyp _x2)
                  | ExVrn (_x0, _x1) -> ExVrn (o#_Loc_t _x0, o#string _x1)
                  | ExWhi (_x0, _x1, _x2) ->
                      ExWhi (o#_Loc_t _x0, o#expr _x1, o#expr _x2)
                method ctyp : ctyp -> ctyp =
                  function
                  | TyNil _x0 -> TyNil (o#_Loc_t _x0)
                  | TyAli (_x0, _x1, _x2) ->
                      TyAli (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyAny _x0 -> TyAny (o#_Loc_t _x0)
                  | TyApp (_x0, _x1, _x2) ->
                      TyApp (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyArr (_x0, _x1, _x2) ->
                      TyArr (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyCls (_x0, _x1) -> TyCls (o#_Loc_t _x0, o#ident _x1)
                  | TyLab (_x0, _x1, _x2) ->
                      TyLab (o#_Loc_t _x0, o#string _x1, o#ctyp _x2)
                  | TyId (_x0, _x1) -> TyId (o#_Loc_t _x0, o#ident _x1)
                  | TyMan (_x0, _x1, _x2) ->
                      TyMan (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyDcl (_x0, _x1, _x2, _x3, _x4) ->
                      TyDcl (o#_Loc_t _x0, o#string _x1, o#list o#ctyp _x2,
                        o#ctyp _x3,
                        o#list
                          (fun (_x0, _x1) -> ((o#ctyp _x0), (o#ctyp _x1)))
                          _x4)
                  | TyObj (_x0, _x1, _x2) ->
                      TyObj (o#_Loc_t _x0, o#ctyp _x1, o#meta_bool _x2)
                  | TyOlb (_x0, _x1, _x2) ->
                      TyOlb (o#_Loc_t _x0, o#string _x1, o#ctyp _x2)
                  | TyPol (_x0, _x1, _x2) ->
                      TyPol (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyQuo (_x0, _x1) -> TyQuo (o#_Loc_t _x0, o#string _x1)
                  | TyQuP (_x0, _x1) -> TyQuP (o#_Loc_t _x0, o#string _x1)
                  | TyQuM (_x0, _x1) -> TyQuM (o#_Loc_t _x0, o#string _x1)
                  | TyVrn (_x0, _x1) -> TyVrn (o#_Loc_t _x0, o#string _x1)
                  | TyRec (_x0, _x1) -> TyRec (o#_Loc_t _x0, o#ctyp _x1)
                  | TyCol (_x0, _x1, _x2) ->
                      TyCol (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TySem (_x0, _x1, _x2) ->
                      TySem (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyCom (_x0, _x1, _x2) ->
                      TyCom (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TySum (_x0, _x1) -> TySum (o#_Loc_t _x0, o#ctyp _x1)
                  | TyOf (_x0, _x1, _x2) ->
                      TyOf (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyAnd (_x0, _x1, _x2) ->
                      TyAnd (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyOr (_x0, _x1, _x2) ->
                      TyOr (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyPrv (_x0, _x1) -> TyPrv (o#_Loc_t _x0, o#ctyp _x1)
                  | TyMut (_x0, _x1) -> TyMut (o#_Loc_t _x0, o#ctyp _x1)
                  | TyTup (_x0, _x1) -> TyTup (o#_Loc_t _x0, o#ctyp _x1)
                  | TySta (_x0, _x1, _x2) ->
                      TySta (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyVrnEq (_x0, _x1) -> TyVrnEq (o#_Loc_t _x0, o#ctyp _x1)
                  | TyVrnSup (_x0, _x1) ->
                      TyVrnSup (o#_Loc_t _x0, o#ctyp _x1)
                  | TyVrnInf (_x0, _x1) ->
                      TyVrnInf (o#_Loc_t _x0, o#ctyp _x1)
                  | TyVrnInfSup (_x0, _x1, _x2) ->
                      TyVrnInfSup (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyAmp (_x0, _x1, _x2) ->
                      TyAmp (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyOfAmp (_x0, _x1, _x2) ->
                      TyOfAmp (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | TyAnt (_x0, _x1) -> TyAnt (o#_Loc_t _x0, o#string _x1)
                method class_type : class_type -> class_type =
                  function
                  | CtNil _x0 -> CtNil (o#_Loc_t _x0)
                  | CtCon (_x0, _x1, _x2, _x3) ->
                      CtCon (o#_Loc_t _x0, o#meta_bool _x1, o#ident _x2,
                        o#ctyp _x3)
                  | CtFun (_x0, _x1, _x2) ->
                      CtFun (o#_Loc_t _x0, o#ctyp _x1, o#class_type _x2)
                  | CtSig (_x0, _x1, _x2) ->
                      CtSig (o#_Loc_t _x0, o#ctyp _x1, o#class_sig_item _x2)
                  | CtAnd (_x0, _x1, _x2) ->
                      CtAnd (o#_Loc_t _x0, o#class_type _x1,
                        o#class_type _x2)
                  | CtCol (_x0, _x1, _x2) ->
                      CtCol (o#_Loc_t _x0, o#class_type _x1,
                        o#class_type _x2)
                  | CtEq (_x0, _x1, _x2) ->
                      CtEq (o#_Loc_t _x0, o#class_type _x1, o#class_type _x2)
                  | CtAnt (_x0, _x1) -> CtAnt (o#_Loc_t _x0, o#string _x1)
                method class_str_item : class_str_item -> class_str_item =
                  function
                  | CrNil _x0 -> CrNil (o#_Loc_t _x0)
                  | CrSem (_x0, _x1, _x2) ->
                      CrSem (o#_Loc_t _x0, o#class_str_item _x1,
                        o#class_str_item _x2)
                  | CrCtr (_x0, _x1, _x2) ->
                      CrCtr (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | CrInh (_x0, _x1, _x2) ->
                      CrInh (o#_Loc_t _x0, o#class_expr _x1, o#string _x2)
                  | CrIni (_x0, _x1) -> CrIni (o#_Loc_t _x0, o#expr _x1)
                  | CrMth (_x0, _x1, _x2, _x3, _x4) ->
                      CrMth (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#expr _x3, o#ctyp _x4)
                  | CrVal (_x0, _x1, _x2, _x3) ->
                      CrVal (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#expr _x3)
                  | CrVir (_x0, _x1, _x2, _x3) ->
                      CrVir (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#ctyp _x3)
                  | CrVvr (_x0, _x1, _x2, _x3) ->
                      CrVvr (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#ctyp _x3)
                  | CrAnt (_x0, _x1) -> CrAnt (o#_Loc_t _x0, o#string _x1)
                method class_sig_item : class_sig_item -> class_sig_item =
                  function
                  | CgNil _x0 -> CgNil (o#_Loc_t _x0)
                  | CgCtr (_x0, _x1, _x2) ->
                      CgCtr (o#_Loc_t _x0, o#ctyp _x1, o#ctyp _x2)
                  | CgSem (_x0, _x1, _x2) ->
                      CgSem (o#_Loc_t _x0, o#class_sig_item _x1,
                        o#class_sig_item _x2)
                  | CgInh (_x0, _x1) ->
                      CgInh (o#_Loc_t _x0, o#class_type _x1)
                  | CgMth (_x0, _x1, _x2, _x3) ->
                      CgMth (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#ctyp _x3)
                  | CgVal (_x0, _x1, _x2, _x3, _x4) ->
                      CgVal (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#meta_bool _x3, o#ctyp _x4)
                  | CgVir (_x0, _x1, _x2, _x3) ->
                      CgVir (o#_Loc_t _x0, o#string _x1, o#meta_bool _x2,
                        o#ctyp _x3)
                  | CgAnt (_x0, _x1) -> CgAnt (o#_Loc_t _x0, o#string _x1)
                method class_expr : class_expr -> class_expr =
                  function
                  | CeNil _x0 -> CeNil (o#_Loc_t _x0)
                  | CeApp (_x0, _x1, _x2) ->
                      CeApp (o#_Loc_t _x0, o#class_expr _x1, o#expr _x2)
                  | CeCon (_x0, _x1, _x2, _x3) ->
                      CeCon (o#_Loc_t _x0, o#meta_bool _x1, o#ident _x2,
                        o#ctyp _x3)
                  | CeFun (_x0, _x1, _x2) ->
                      CeFun (o#_Loc_t _x0, o#patt _x1, o#class_expr _x2)
                  | CeLet (_x0, _x1, _x2, _x3) ->
                      CeLet (o#_Loc_t _x0, o#meta_bool _x1, o#binding _x2,
                        o#class_expr _x3)
                  | CeStr (_x0, _x1, _x2) ->
                      CeStr (o#_Loc_t _x0, o#patt _x1, o#class_str_item _x2)
                  | CeTyc (_x0, _x1, _x2) ->
                      CeTyc (o#_Loc_t _x0, o#class_expr _x1,
                        o#class_type _x2)
                  | CeAnd (_x0, _x1, _x2) ->
                      CeAnd (o#_Loc_t _x0, o#class_expr _x1,
                        o#class_expr _x2)
                  | CeEq (_x0, _x1, _x2) ->
                      CeEq (o#_Loc_t _x0, o#class_expr _x1, o#class_expr _x2)
                  | CeAnt (_x0, _x1) -> CeAnt (o#_Loc_t _x0, o#string _x1)
                method binding : binding -> binding =
                  function
                  | BiNil _x0 -> BiNil (o#_Loc_t _x0)
                  | BiAnd (_x0, _x1, _x2) ->
                      BiAnd (o#_Loc_t _x0, o#binding _x1, o#binding _x2)
                  | BiSem (_x0, _x1, _x2) ->
                      BiSem (o#_Loc_t _x0, o#binding _x1, o#binding _x2)
                  | BiEq (_x0, _x1, _x2) ->
                      BiEq (o#_Loc_t _x0, o#patt _x1, o#expr _x2)
                  | BiAnt (_x0, _x1) -> BiAnt (o#_Loc_t _x0, o#string _x1)
              end
            class fold =
              object ((o : 'self_type))
                method string = fun (_ : string) -> (o : 'self_type)
                method int = fun (_ : int) -> (o : 'self_type)
                method float = fun (_ : float) -> (o : 'self_type)
                method bool = fun (_ : bool) -> (o : 'self_type)
                method list :
                  'a.
                    ('self_type -> 'a -> 'self_type) -> 'a list -> 'self_type =
                  fun f -> List.fold_left f o
                method option :
                  'a.
                    ('self_type -> 'a -> 'self_type) ->
                      'a option -> 'self_type =
                  fun f -> function | None -> o | Some x -> f o x
                method array :
                  'a.
                    ('self_type -> 'a -> 'self_type) ->
                      'a array -> 'self_type =
                  fun f -> Array.fold_left f o
                method ref :
                  'a.
                    ('self_type -> 'a -> 'self_type) -> 'a ref -> 'self_type =
                  fun f { contents = x } -> f o x
                method _Loc_t : Loc.t -> 'self_type = fun _ -> o
                method with_constr : with_constr -> 'self_type =
                  function
                  | WcNil _x0 -> o#_Loc_t _x0
                  | WcTyp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | WcMod (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ident _x1)#ident _x2
                  | WcAnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#with_constr _x1)#with_constr _x2
                  | WcAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method str_item : str_item -> 'self_type =
                  function
                  | StNil _x0 -> o#_Loc_t _x0
                  | StCls (_x0, _x1) -> (o#_Loc_t _x0)#class_expr _x1
                  | StClt (_x0, _x1) -> (o#_Loc_t _x0)#class_type _x1
                  | StSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#str_item _x1)#str_item _x2
                  | StDir (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#expr _x2
                  | StExc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#meta_option
                        (fun o -> o#ident) _x2
                  | StExp (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | StExt (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#ctyp _x2)#string _x3
                  | StInc (_x0, _x1) -> (o#_Loc_t _x0)#module_expr _x1
                  | StMod (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#module_expr _x2
                  | StRecMod (_x0, _x1) -> (o#_Loc_t _x0)#module_binding _x1
                  | StMty (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#module_type _x2
                  | StOpn (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | StTyp (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | StVal (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#meta_bool _x1)#binding _x2
                  | StAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method sig_item : sig_item -> 'self_type =
                  function
                  | SgNil _x0 -> o#_Loc_t _x0
                  | SgCls (_x0, _x1) -> (o#_Loc_t _x0)#class_type _x1
                  | SgClt (_x0, _x1) -> (o#_Loc_t _x0)#class_type _x1
                  | SgSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#sig_item _x1)#sig_item _x2
                  | SgDir (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#expr _x2
                  | SgExc (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | SgExt (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#ctyp _x2)#string _x3
                  | SgInc (_x0, _x1) -> (o#_Loc_t _x0)#module_type _x1
                  | SgMod (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#module_type _x2
                  | SgRecMod (_x0, _x1) -> (o#_Loc_t _x0)#module_binding _x1
                  | SgMty (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#module_type _x2
                  | SgOpn (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | SgTyp (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | SgVal (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#ctyp _x2
                  | SgAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method patt : patt -> 'self_type =
                  function
                  | PaNil _x0 -> o#_Loc_t _x0
                  | PaId (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | PaAli (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaAny _x0 -> o#_Loc_t _x0
                  | PaApp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaArr (_x0, _x1) -> (o#_Loc_t _x0)#patt _x1
                  | PaCom (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaChr (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaInt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaInt32 (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaInt64 (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaNativeInt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaFlo (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaLab (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#patt _x2
                  | PaOlb (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#patt _x2
                  | PaOlbi (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#patt _x2)#expr _x3
                  | PaOrp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaRng (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaRec (_x0, _x1) -> (o#_Loc_t _x0)#patt _x1
                  | PaEq (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#patt _x2
                  | PaStr (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | PaTup (_x0, _x1) -> (o#_Loc_t _x0)#patt _x1
                  | PaTyc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#ctyp _x2
                  | PaTyp (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | PaVrn (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method module_type : module_type -> 'self_type =
                  function
                  | MtId (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | MtFun (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#module_type _x2)#
                        module_type _x3
                  | MtQuo (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | MtSig (_x0, _x1) -> (o#_Loc_t _x0)#sig_item _x1
                  | MtWit (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#module_type _x1)#with_constr _x2
                  | MtAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method module_expr : module_expr -> 'self_type =
                  function
                  | MeId (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | MeApp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#module_expr _x1)#module_expr _x2
                  | MeFun (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#module_type _x2)#
                        module_expr _x3
                  | MeStr (_x0, _x1) -> (o#_Loc_t _x0)#str_item _x1
                  | MeTyc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#module_expr _x1)#module_type _x2
                  | MeAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method module_binding : module_binding -> 'self_type =
                  function
                  | MbNil _x0 -> o#_Loc_t _x0
                  | MbAnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#module_binding _x1)#module_binding _x2
                  | MbColEq (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#module_type _x2)#
                        module_expr _x3
                  | MbCol (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#module_type _x2
                  | MbAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method meta_option :
                  'a.
                    ('self_type -> 'a -> 'self_type) ->
                      'a meta_option -> 'self_type =
                  fun _f_a ->
                    function
                    | ONone -> o
                    | OSome _x0 -> _f_a o _x0
                    | OAnt _x0 -> o#string _x0
                method meta_bool : meta_bool -> 'self_type =
                  function
                  | BTrue -> o
                  | BFalse -> o
                  | BAnt _x0 -> o#string _x0
                method match_case : match_case -> 'self_type =
                  function
                  | McNil _x0 -> o#_Loc_t _x0
                  | McOr (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#match_case _x1)#match_case _x2
                  | McArr (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#patt _x1)#expr _x2)#expr _x3
                  | McAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method ident : ident -> 'self_type =
                  function
                  | IdAcc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ident _x1)#ident _x2
                  | IdApp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ident _x1)#ident _x2
                  | IdLid (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | IdUid (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | IdAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method expr : expr -> 'self_type =
                  function
                  | ExNil _x0 -> o#_Loc_t _x0
                  | ExId (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | ExAcc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExApp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExAre (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExArr (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | ExSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExAsf _x0 -> o#_Loc_t _x0
                  | ExAsr (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | ExAss (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExChr (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExCoe (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#expr _x1)#ctyp _x2)#ctyp _x3
                  | ExFlo (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExFor (_x0, _x1, _x2, _x3, _x4, _x5) ->
                      (((((o#_Loc_t _x0)#string _x1)#expr _x2)#expr _x3)#
                         meta_bool _x4)#
                        expr _x5
                  | ExFun (_x0, _x1) -> (o#_Loc_t _x0)#match_case _x1
                  | ExIfe (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#expr _x1)#expr _x2)#expr _x3
                  | ExInt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExInt32 (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExInt64 (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExNativeInt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExLab (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#expr _x2
                  | ExLaz (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | ExLet (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#meta_bool _x1)#binding _x2)#expr _x3
                  | ExLmd (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#module_expr _x2)#expr _x3
                  | ExMat (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#match_case _x2
                  | ExNew (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | ExObj (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#class_str_item _x2
                  | ExOlb (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#expr _x2
                  | ExOvr (_x0, _x1) -> (o#_Loc_t _x0)#binding _x1
                  | ExRec (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#binding _x1)#expr _x2
                  | ExSeq (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | ExSnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#string _x2
                  | ExSte (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExStr (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExTry (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#match_case _x2
                  | ExTup (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | ExCom (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                  | ExTyc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#ctyp _x2
                  | ExVrn (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | ExWhi (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#expr _x1)#expr _x2
                method ctyp : ctyp -> 'self_type =
                  function
                  | TyNil _x0 -> o#_Loc_t _x0
                  | TyAli (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyAny _x0 -> o#_Loc_t _x0
                  | TyApp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyArr (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyCls (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | TyLab (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#ctyp _x2
                  | TyId (_x0, _x1) -> (o#_Loc_t _x0)#ident _x1
                  | TyMan (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyDcl (_x0, _x1, _x2, _x3, _x4) ->
                      ((((o#_Loc_t _x0)#string _x1)#list (fun o -> o#ctyp)
                          _x2)#
                         ctyp _x3)#
                        list (fun o (_x0, _x1) -> (o#ctyp _x0)#ctyp _x1) _x4
                  | TyObj (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#meta_bool _x2
                  | TyOlb (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#string _x1)#ctyp _x2
                  | TyPol (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyQuo (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | TyQuP (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | TyQuM (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | TyVrn (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                  | TyRec (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyCol (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TySem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyCom (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TySum (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyOf (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyAnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyOr (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyPrv (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyMut (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyTup (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TySta (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyVrnEq (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyVrnSup (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyVrnInf (_x0, _x1) -> (o#_Loc_t _x0)#ctyp _x1
                  | TyVrnInfSup (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyAmp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyOfAmp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | TyAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method class_type : class_type -> 'self_type =
                  function
                  | CtNil _x0 -> o#_Loc_t _x0
                  | CtCon (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#meta_bool _x1)#ident _x2)#ctyp _x3
                  | CtFun (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#class_type _x2
                  | CtSig (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#class_sig_item _x2
                  | CtAnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_type _x1)#class_type _x2
                  | CtCol (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_type _x1)#class_type _x2
                  | CtEq (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_type _x1)#class_type _x2
                  | CtAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method class_str_item : class_str_item -> 'self_type =
                  function
                  | CrNil _x0 -> o#_Loc_t _x0
                  | CrSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_str_item _x1)#class_str_item _x2
                  | CrCtr (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | CrInh (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_expr _x1)#string _x2
                  | CrIni (_x0, _x1) -> (o#_Loc_t _x0)#expr _x1
                  | CrMth (_x0, _x1, _x2, _x3, _x4) ->
                      ((((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#expr _x3)#
                        ctyp _x4
                  | CrVal (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#expr _x3
                  | CrVir (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#ctyp _x3
                  | CrVvr (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#ctyp _x3
                  | CrAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method class_sig_item : class_sig_item -> 'self_type =
                  function
                  | CgNil _x0 -> o#_Loc_t _x0
                  | CgCtr (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#ctyp _x1)#ctyp _x2
                  | CgSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_sig_item _x1)#class_sig_item _x2
                  | CgInh (_x0, _x1) -> (o#_Loc_t _x0)#class_type _x1
                  | CgMth (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#ctyp _x3
                  | CgVal (_x0, _x1, _x2, _x3, _x4) ->
                      ((((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#meta_bool
                         _x3)#
                        ctyp _x4
                  | CgVir (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#string _x1)#meta_bool _x2)#ctyp _x3
                  | CgAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method class_expr : class_expr -> 'self_type =
                  function
                  | CeNil _x0 -> o#_Loc_t _x0
                  | CeApp (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_expr _x1)#expr _x2
                  | CeCon (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#meta_bool _x1)#ident _x2)#ctyp _x3
                  | CeFun (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#class_expr _x2
                  | CeLet (_x0, _x1, _x2, _x3) ->
                      (((o#_Loc_t _x0)#meta_bool _x1)#binding _x2)#class_expr
                        _x3
                  | CeStr (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#class_str_item _x2
                  | CeTyc (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_expr _x1)#class_type _x2
                  | CeAnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_expr _x1)#class_expr _x2
                  | CeEq (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#class_expr _x1)#class_expr _x2
                  | CeAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
                method binding : binding -> 'self_type =
                  function
                  | BiNil _x0 -> o#_Loc_t _x0
                  | BiAnd (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#binding _x1)#binding _x2
                  | BiSem (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#binding _x1)#binding _x2
                  | BiEq (_x0, _x1, _x2) ->
                      ((o#_Loc_t _x0)#patt _x1)#expr _x2
                  | BiAnt (_x0, _x1) -> (o#_Loc_t _x0)#string _x1
              end
            class c_expr f =
              object inherit map as super
                method expr = fun x -> f (super#expr x)
              end
            class c_patt f =
              object inherit map as super
                method patt = fun x -> f (super#patt x)
              end
            class c_ctyp f =
              object inherit map as super
                method ctyp = fun x -> f (super#ctyp x)
              end
            class c_str_item f =
              object inherit map as super
                method str_item = fun x -> f (super#str_item x)
              end
            class c_sig_item f =
              object inherit map as super
                method sig_item = fun x -> f (super#sig_item x)
              end
            class c_loc f =
              object inherit map as super
                method _Loc_t = fun x -> f (super#_Loc_t x)
              end
            let map_patt f ast = (new c_patt f)#patt ast
            let map_loc f ast = (new c_loc f)#_Loc_t ast
            let map_sig_item f ast = (new c_sig_item f)#sig_item ast
            let map_str_item f ast = (new c_str_item f)#str_item ast
            let map_ctyp f ast = (new c_ctyp f)#ctyp ast
            let map_expr f ast = (new c_expr f)#expr ast
            let ghost = Loc.ghost
            let rec is_module_longident =
              function
              | Ast.IdAcc (_, _, i) -> is_module_longident i
              | Ast.IdApp (_, i1, i2) ->
                  (is_module_longident i1) && (is_module_longident i2)
              | Ast.IdUid (_, _) -> true
              | _ -> false
            let rec is_irrefut_patt =
              function
              | Ast.PaId (_, (Ast.IdLid (_, _))) -> true
              | Ast.PaId (_, (Ast.IdUid (_, "()"))) -> true
              | Ast.PaAny _ -> true
              | Ast.PaAli (_, x, y) ->
                  (is_irrefut_patt x) && (is_irrefut_patt y)
              | Ast.PaRec (_, p) -> is_irrefut_patt p
              | Ast.PaEq (_, (Ast.PaId (_, (Ast.IdLid (_, _)))), p) ->
                  is_irrefut_patt p
              | Ast.PaSem (_, p1, p2) ->
                  (is_irrefut_patt p1) && (is_irrefut_patt p2)
              | Ast.PaCom (_, p1, p2) ->
                  (is_irrefut_patt p1) && (is_irrefut_patt p2)
              | Ast.PaTyc (_, p, _) -> is_irrefut_patt p
              | Ast.PaTup (_, pl) -> is_irrefut_patt pl
              | Ast.PaOlb (_, _, (Ast.PaNil _)) -> true
              | Ast.PaOlb (_, _, p) -> is_irrefut_patt p
              | Ast.PaOlbi (_, _, p, _) -> is_irrefut_patt p
              | Ast.PaLab (_, _, (Ast.PaNil _)) -> true
              | Ast.PaLab (_, _, p) -> is_irrefut_patt p
              | _ -> false
            let rec is_constructor =
              function
              | Ast.IdAcc (_, _, i) -> is_constructor i
              | Ast.IdUid (_, _) -> true
              | Ast.IdLid (_, _) | Ast.IdApp (_, _, _) -> false
              | Ast.IdAnt (_, _) -> assert false
            let is_patt_constructor =
              function
              | Ast.PaId (_, i) -> is_constructor i
              | Ast.PaVrn (_, _) -> true
              | _ -> false
            let rec is_expr_constructor =
              function
              | Ast.ExId (_, i) -> is_constructor i
              | Ast.ExAcc (_, e1, e2) ->
                  (is_expr_constructor e1) && (is_expr_constructor e2)
              | Ast.ExVrn (_, _) -> true
              | _ -> false
            let ident_of_expr =
              let error () =
                invalid_arg
                  "ident_of_expr: this expression is not an identifier" in
              let rec self =
                function
                | Ast.ExApp (_loc, e1, e2) ->
                    Ast.IdApp (_loc, self e1, self e2)
                | Ast.ExAcc (_loc, e1, e2) ->
                    Ast.IdAcc (_loc, self e1, self e2)
                | Ast.ExId (_, (Ast.IdLid (_, _))) -> error ()
                | Ast.ExId (_, i) ->
                    if is_module_longident i then i else error ()
                | _ -> error ()
              in
                function
                | Ast.ExId (_, i) -> i
                | Ast.ExApp (_, _, _) -> error ()
                | t -> self t
            let ident_of_ctyp =
              let error () =
                invalid_arg "ident_of_ctyp: this type is not an identifier" in
              let rec self =
                function
                | Ast.TyApp (_loc, t1, t2) ->
                    Ast.IdApp (_loc, self t1, self t2)
                | Ast.TyId (_, (Ast.IdLid (_, _))) -> error ()
                | Ast.TyId (_, i) ->
                    if is_module_longident i then i else error ()
                | _ -> error ()
              in function | Ast.TyId (_, i) -> i | t -> self t
            let rec tyOr_of_list =
              function
              | [] -> Ast.TyNil ghost
              | [ t ] -> t
              | t :: ts ->
                  let _loc = loc_of_ctyp t
                  in Ast.TyOr (_loc, t, tyOr_of_list ts)
            let rec tyAnd_of_list =
              function
              | [] -> Ast.TyNil ghost
              | [ t ] -> t
              | t :: ts ->
                  let _loc = loc_of_ctyp t
                  in Ast.TyAnd (_loc, t, tyAnd_of_list ts)
            let rec tySem_of_list =
              function
              | [] -> Ast.TyNil ghost
              | [ t ] -> t
              | t :: ts ->
                  let _loc = loc_of_ctyp t
                  in Ast.TySem (_loc, t, tySem_of_list ts)
            let rec stSem_of_list =
              function
              | [] -> Ast.StNil ghost
              | [ t ] -> t
              | t :: ts ->
                  let _loc = loc_of_str_item t
                  in Ast.StSem (_loc, t, stSem_of_list ts)
            let rec sgSem_of_list =
              function
              | [] -> Ast.SgNil ghost
              | [ t ] -> t
              | t :: ts ->
                  let _loc = loc_of_sig_item t
                  in Ast.SgSem (_loc, t, sgSem_of_list ts)
            let rec biAnd_of_list =
              function
              | [] -> Ast.BiNil ghost
              | [ b ] -> b
              | b :: bs ->
                  let _loc = loc_of_binding b
                  in Ast.BiAnd (_loc, b, biAnd_of_list bs)
            let rec wcAnd_of_list =
              function
              | [] -> Ast.WcNil ghost
              | [ w ] -> w
              | w :: ws ->
                  let _loc = loc_of_with_constr w
                  in Ast.WcAnd (_loc, w, wcAnd_of_list ws)
            let rec idAcc_of_list =
              function
              | [] -> assert false
              | [ i ] -> i
              | i :: is ->
                  let _loc = loc_of_ident i
                  in Ast.IdAcc (_loc, i, idAcc_of_list is)
            let rec idApp_of_list =
              function
              | [] -> assert false
              | [ i ] -> i
              | i :: is ->
                  let _loc = loc_of_ident i
                  in Ast.IdApp (_loc, i, idApp_of_list is)
            let rec mcOr_of_list =
              function
              | [] -> Ast.McNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_match_case x
                  in Ast.McOr (_loc, x, mcOr_of_list xs)
            let rec mbAnd_of_list =
              function
              | [] -> Ast.MbNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_module_binding x
                  in Ast.MbAnd (_loc, x, mbAnd_of_list xs)
            let rec meApp_of_list =
              function
              | [] -> assert false
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_module_expr x
                  in Ast.MeApp (_loc, x, meApp_of_list xs)
            let rec ceAnd_of_list =
              function
              | [] -> Ast.CeNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_class_expr x
                  in Ast.CeAnd (_loc, x, ceAnd_of_list xs)
            let rec ctAnd_of_list =
              function
              | [] -> Ast.CtNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_class_type x
                  in Ast.CtAnd (_loc, x, ctAnd_of_list xs)
            let rec cgSem_of_list =
              function
              | [] -> Ast.CgNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_class_sig_item x
                  in Ast.CgSem (_loc, x, cgSem_of_list xs)
            let rec crSem_of_list =
              function
              | [] -> Ast.CrNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_class_str_item x
                  in Ast.CrSem (_loc, x, crSem_of_list xs)
            let rec paSem_of_list =
              function
              | [] -> Ast.PaNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_patt x
                  in Ast.PaSem (_loc, x, paSem_of_list xs)
            let rec paCom_of_list =
              function
              | [] -> Ast.PaNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_patt x
                  in Ast.PaCom (_loc, x, paCom_of_list xs)
            let rec biSem_of_list =
              function
              | [] -> Ast.BiNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_binding x
                  in Ast.BiSem (_loc, x, biSem_of_list xs)
            let rec exSem_of_list =
              function
              | [] -> Ast.ExNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_expr x
                  in Ast.ExSem (_loc, x, exSem_of_list xs)
            let rec exCom_of_list =
              function
              | [] -> Ast.ExNil ghost
              | [ x ] -> x
              | x :: xs ->
                  let _loc = loc_of_expr x
                  in Ast.ExCom (_loc, x, exCom_of_list xs)
            let ty_of_stl =
              function
              | (_loc, s, []) -> Ast.TyId (_loc, Ast.IdUid (_loc, s))
              | (_loc, s, tl) ->
                  Ast.TyOf (_loc, Ast.TyId (_loc, Ast.IdUid (_loc, s)),
                    tyAnd_of_list tl)
            let ty_of_sbt =
              function
              | (_loc, s, true, t) ->
                  Ast.TyCol (_loc, Ast.TyId (_loc, Ast.IdLid (_loc, s)),
                    Ast.TyMut (_loc, t))
              | (_loc, s, false, t) ->
                  Ast.TyCol (_loc, Ast.TyId (_loc, Ast.IdLid (_loc, s)), t)
            let bi_of_pe (p, e) =
              let _loc = loc_of_patt p in Ast.BiEq (_loc, p, e)
            let sum_type_of_list l = tyOr_of_list (List.map ty_of_stl l)
            let record_type_of_list l = tySem_of_list (List.map ty_of_sbt l)
            let binding_of_pel l = biAnd_of_list (List.map bi_of_pe l)
            let rec pel_of_binding =
              function
              | Ast.BiAnd (_, b1, b2) ->
                  (pel_of_binding b1) @ (pel_of_binding b2)
              | Ast.BiEq (_, p, e) -> [ (p, e) ]
              | Ast.BiSem (_, b1, b2) ->
                  (pel_of_binding b1) @ (pel_of_binding b2)
              | _ -> assert false
            let rec list_of_binding x acc =
              match x with
              | Ast.BiAnd (_, b1, b2) | Ast.BiSem (_, b1, b2) ->
                  list_of_binding b1 (list_of_binding b2 acc)
              | t -> t :: acc
            let rec list_of_with_constr x acc =
              match x with
              | Ast.WcAnd (_, w1, w2) ->
                  list_of_with_constr w1 (list_of_with_constr w2 acc)
              | t -> t :: acc
            let rec list_of_ctyp x acc =
              match x with
              | Ast.TyNil _ -> acc
              | Ast.TyAmp (_, x, y) | Ast.TyCom (_, x, y) |
                  Ast.TySta (_, x, y) | Ast.TySem (_, x, y) |
                  Ast.TyAnd (_, x, y) | Ast.TyOr (_, x, y) ->
                  list_of_ctyp x (list_of_ctyp y acc)
              | x -> x :: acc
            let rec list_of_patt x acc =
              match x with
              | Ast.PaNil _ -> acc
              | Ast.PaCom (_, x, y) | Ast.PaSem (_, x, y) ->
                  list_of_patt x (list_of_patt y acc)
              | x -> x :: acc
            let rec list_of_expr x acc =
              match x with
              | Ast.ExNil _ -> acc
              | Ast.ExCom (_, x, y) | Ast.ExSem (_, x, y) ->
                  list_of_expr x (list_of_expr y acc)
              | x -> x :: acc
            let rec list_of_str_item x acc =
              match x with
              | Ast.StNil _ -> acc
              | Ast.StSem (_, x, y) ->
                  list_of_str_item x (list_of_str_item y acc)
              | x -> x :: acc
            let rec list_of_sig_item x acc =
              match x with
              | Ast.SgNil _ -> acc
              | Ast.SgSem (_, x, y) ->
                  list_of_sig_item x (list_of_sig_item y acc)
              | x -> x :: acc
            let rec list_of_class_sig_item x acc =
              match x with
              | Ast.CgNil _ -> acc
              | Ast.CgSem (_, x, y) ->
                  list_of_class_sig_item x (list_of_class_sig_item y acc)
              | x -> x :: acc
            let rec list_of_class_str_item x acc =
              match x with
              | Ast.CrNil _ -> acc
              | Ast.CrSem (_, x, y) ->
                  list_of_class_str_item x (list_of_class_str_item y acc)
              | x -> x :: acc
            let rec list_of_class_type x acc =
              match x with
              | Ast.CtAnd (_, x, y) ->
                  list_of_class_type x (list_of_class_type y acc)
              | x -> x :: acc
            let rec list_of_class_expr x acc =
              match x with
              | Ast.CeAnd (_, x, y) ->
                  list_of_class_expr x (list_of_class_expr y acc)
              | x -> x :: acc
            let rec list_of_module_expr x acc =
              match x with
              | Ast.MeApp (_, x, y) ->
                  list_of_module_expr x (list_of_module_expr y acc)
              | x -> x :: acc
            let rec list_of_match_case x acc =
              match x with
              | Ast.McNil _ -> acc
              | Ast.McOr (_, x, y) ->
                  list_of_match_case x (list_of_match_case y acc)
              | x -> x :: acc
            let rec list_of_ident x acc =
              match x with
              | Ast.IdAcc (_, x, y) | Ast.IdApp (_, x, y) ->
                  list_of_ident x (list_of_ident y acc)
              | x -> x :: acc
            let rec list_of_module_binding x acc =
              match x with
              | Ast.MbAnd (_, x, y) ->
                  list_of_module_binding x (list_of_module_binding y acc)
              | x -> x :: acc
          end
      end
    module Quotation =
      struct
        module Make (Ast : Sig.Ast) : Sig.Quotation with module Ast = Ast =
          struct
            module Ast = Ast
            module Loc = Ast.Loc
            open Format
            open Sig
            type 'a expand_fun = Loc.t -> string option -> string -> 'a
            type expander =
              | ExStr of (bool -> string expand_fun)
              | ExAst of Ast.expr expand_fun * Ast.patt expand_fun
            let expanders_table = ref []
            let default = ref ""
            let translate = ref (fun x -> x)
            let expander_name name =
              match !translate name with | "" -> !default | name -> name
            let find name = List.assoc (expander_name name) !expanders_table
            let add name f = expanders_table := (name, f) :: !expanders_table
            let dump_file = ref None
            module Error =
              struct
                type error =
                  | Finding | Expanding | ParsingResult of Loc.t * string
                  | Locating
                type t = (string * error * exn)
                exception E of t
                let print ppf (name, ctx, exn) =
                  let name = if name = "" then !default else name in
                  let pp x = fprintf ppf "@?@[<2>While %s %S:" x name in
                  let () =
                    match ctx with
                    | Finding ->
                        (pp "finding quotation";
                         fprintf ppf " available quotations are:\n@[<2>";
                         List.iter (fun (s, _) -> fprintf ppf "%s@ " s)
                           !expanders_table;
                         fprintf ppf "@]")
                    | Expanding -> pp "expanding quotation"
                    | Locating -> pp "parsing"
                    | ParsingResult (loc, str) ->
                        let () = pp "parsing result of quotation"
                        in
                          (match !dump_file with
                           | Some dump_file ->
                               let () = fprintf ppf " dumping result...\n"
                               in
                                 (try
                                    let oc = open_out_bin dump_file
                                    in
                                      (output_string oc str;
                                       output_string oc "\n";
                                       flush oc;
                                       close_out oc;
                                       fprintf ppf "%a:" Loc.print
                                         (Loc.set_file_name dump_file loc))
                                  with
                                  | _ ->
                                      fprintf ppf
                                        "Error while dumping result in file %S; dump aborted"
                                        dump_file)
                           | None ->
                               fprintf ppf
                                 "\n(consider setting variable Quotation.dump_file, or using the -QD option)")
                  in fprintf ppf "@\n%a@]@." ErrorHandler.print exn
                let to_string x =
                  let b = Buffer.create 50 in
                  let () = bprintf b "%a" print x in Buffer.contents b
              end
            let _ = let module M = ErrorHandler.Register(Error) in ()
            open Error
            let expand_quotation loc expander quot =
              let loc_name_opt =
                if quot.q_loc = "" then None else Some quot.q_loc
              in
                try expander loc loc_name_opt quot.q_contents
                with | (Loc.Exc_located (_, (Error.E _)) as exc) -> raise exc
                | Loc.Exc_located (iloc, exc) ->
                    let exc1 = Error.E (((quot.q_name), Expanding, exc))
                    in raise (Loc.Exc_located (iloc, exc1))
                | exc ->
                    let exc1 = Error.E (((quot.q_name), Expanding, exc))
                    in raise (Loc.Exc_located (loc, exc1))
            let parse_quotation_result parse loc quot str =
              try parse loc str
              with
              | Loc.Exc_located (iloc, (Error.E ((n, Expanding, exc)))) ->
                  let ctx = ParsingResult (iloc, quot.q_contents) in
                  let exc1 = Error.E ((n, ctx, exc))
                  in raise (Loc.Exc_located (iloc, exc1))
              | Loc.Exc_located (iloc, ((Error.E _ as exc))) ->
                  raise (Loc.Exc_located (iloc, exc))
              | Loc.Exc_located (iloc, exc) ->
                  let ctx = ParsingResult (iloc, quot.q_contents) in
                  let exc1 = Error.E (((quot.q_name), ctx, exc))
                  in raise (Loc.Exc_located (iloc, exc1))
            let handle_quotation loc proj in_expr parse quotation =
              let name = quotation.q_name in
              let expander =
                try find name
                with | (Loc.Exc_located (_, (Error.E _)) as exc) -> raise exc
                | Loc.Exc_located (qloc, exc) ->
                    raise
                      (Loc.Exc_located (qloc, Error.E ((name, Finding, exc))))
                | exc ->
                    raise
                      (Loc.Exc_located (loc, Error.E ((name, Finding, exc)))) in
              let loc = Loc.join (Loc.move `start quotation.q_shift loc)
              in
                match expander with
                | ExStr f ->
                    let new_str = expand_quotation loc (f in_expr) quotation
                    in parse_quotation_result parse loc quotation new_str
                | ExAst (fe, fp) ->
                    expand_quotation loc (proj (fe, fp)) quotation
            let expand_expr parse loc x =
              handle_quotation loc fst true parse x
            let expand_patt parse loc x =
              handle_quotation loc snd false parse x
          end
      end
    module AstFilters =
      struct
        module Make (Ast : Sig.Camlp4Ast) :
          Sig.AstFilters with module Ast = Ast =
          struct
            module Ast = Ast
            type 'a filter = 'a -> 'a
            let interf_filters = Queue.create ()
            let fold_interf_filters f i = Queue.fold f i interf_filters
            let implem_filters = Queue.create ()
            let fold_implem_filters f i = Queue.fold f i implem_filters
            let register_sig_item_filter f = Queue.add f interf_filters
            let register_str_item_filter f = Queue.add f implem_filters
          end
      end
    module Camlp4Ast2OCamlAst :
      sig
        module Make (Camlp4Ast : Sig.Camlp4Ast) :
          sig
            open Camlp4Ast
            val sig_item : sig_item -> Parsetree.signature
            val str_item : str_item -> Parsetree.structure
            val phrase : str_item -> Parsetree.toplevel_phrase
          end
      end =
      struct
        module Make (Ast : Sig.Camlp4Ast) =
          struct
            open Format
            open Parsetree
            open Longident
            open Asttypes
            open Ast
            let constructors_arity () = !Camlp4_config.constructors_arity
            let error loc str = Loc.raise loc (Failure str)
            let char_of_char_token loc s =
              try Token.Eval.char s
              with | (Failure _ as exn) -> Loc.raise loc exn
            let string_of_string_token loc s =
              try Token.Eval.string s
              with | (Failure _ as exn) -> Loc.raise loc exn
            let mkloc = Loc.to_ocaml_location
            let mkghloc loc = Loc.to_ocaml_location (Loc.ghostify loc)
            let mktyp loc d = {  ptyp_desc = d; ptyp_loc = mkloc loc; }
            let mkpat loc d = {  ppat_desc = d; ppat_loc = mkloc loc; }
            let mkghpat loc d = {  ppat_desc = d; ppat_loc = mkghloc loc; }
            let mkexp loc d = {  pexp_desc = d; pexp_loc = mkloc loc; }
            let mkmty loc d = {  pmty_desc = d; pmty_loc = mkloc loc; }
            let mksig loc d = {  psig_desc = d; psig_loc = mkloc loc; }
            let mkmod loc d = {  pmod_desc = d; pmod_loc = mkloc loc; }
            let mkstr loc d = {  pstr_desc = d; pstr_loc = mkloc loc; }
            let mkfield loc d = {  pfield_desc = d; pfield_loc = mkloc loc; }
            let mkcty loc d = {  pcty_desc = d; pcty_loc = mkloc loc; }
            let mkpcl loc d = {  pcl_desc = d; pcl_loc = mkloc loc; }
            let mkpolytype t =
              match t.ptyp_desc with
              | Ptyp_poly (_, _) -> t
              | _ -> { (t) with  ptyp_desc = Ptyp_poly ([], t); }
            let mb2b =
              function
              | Ast.BTrue -> true
              | Ast.BFalse -> false
              | Ast.BAnt _ -> assert false
            let mkvirtual m = if mb2b m then Virtual else Concrete
            let lident s = Lident s
            let ldot l s = Ldot (l, s)
            let lapply l s = Lapply (l, s)
            let conv_con =
              let t = Hashtbl.create 73
              in
                (List.iter (fun (s, s') -> Hashtbl.add t s s')
                   [ ("True", "true"); ("False", "false"); (" True", "True");
                     (" False", "False") ];
                 fun s -> try Hashtbl.find t s with | Not_found -> s)
            let conv_lab =
              let t = Hashtbl.create 73
              in
                (List.iter (fun (s, s') -> Hashtbl.add t s s')
                   [ ("val", "contents") ];
                 fun s -> try Hashtbl.find t s with | Not_found -> s)
            let array_function str name =
              ldot (lident str)
                (if !Camlp4_config.unsafe then "unsafe_" ^ name else name)
            let mkrf =
              function
              | Ast.BTrue -> Recursive
              | Ast.BFalse -> Nonrecursive
              | Ast.BAnt _ -> assert false
            let mkli s =
              let rec loop f =
                function
                | i :: il -> loop (fun s -> ldot (f i) s) il
                | [] -> f s
              in loop (fun s -> lident s)
            let rec ctyp_fa al =
              function
              | TyApp (_, f, a) -> ctyp_fa (a :: al) f
              | f -> (f, al)
            let ident_tag ?(conv_lid = fun x -> x) i =
              let rec self i acc =
                match i with
                | Ast.IdAcc (_, i1, i2) -> self i2 (Some (self i1 acc))
                | Ast.IdApp (_, i1, i2) ->
                    let i' =
                      Lapply (fst (self i1 None), fst (self i2 None)) in
                    let x =
                      (match acc with
                       | None -> i'
                       | _ ->
                           error (loc_of_ident i) "invalid long identifier")
                    in (x, `app)
                | Ast.IdUid (_, s) ->
                    let x =
                      (match acc with
                       | None -> lident s
                       | Some ((acc, (`uident | `app))) -> ldot acc s
                       | _ ->
                           error (loc_of_ident i) "invalid long identifier")
                    in (x, `uident)
                | Ast.IdLid (_, s) ->
                    let x =
                      (match acc with
                       | None -> lident (conv_lid s)
                       | Some ((acc, (`uident | `app))) ->
                           ldot acc (conv_lid s)
                       | _ ->
                           error (loc_of_ident i) "invalid long identifier")
                    in (x, `lident)
                | _ -> error (loc_of_ident i) "invalid long identifier"
              in self i None
            let ident ?conv_lid i = fst (ident_tag ?conv_lid i)
            let long_lident msg i =
              match ident_tag i with
              | (i, `lident) -> i
              | _ -> error (loc_of_ident i) msg
            let long_type_ident = long_lident "invalid long identifier type"
            let long_class_ident = long_lident "invalid class name"
            let long_uident ?(conv_con = fun x -> x) i =
              match ident_tag i with
              | (Ldot (i, s), `uident) -> ldot i (conv_con s)
              | (Lident s, `uident) -> lident (conv_con s)
              | (i, `app) -> i
              | _ -> error (loc_of_ident i) "uppercase identifier expected"
            let rec ctyp_long_id_prefix t =
              match t with
              | Ast.TyId (_, i) -> ident i
              | Ast.TyApp (_, m1, m2) ->
                  let li1 = ctyp_long_id_prefix m1 in
                  let li2 = ctyp_long_id_prefix m2 in Lapply (li1, li2)
              | t -> error (loc_of_ctyp t) "invalid module expression"
            let ctyp_long_id t =
              match t with
              | Ast.TyId (_, i) -> (false, (long_type_ident i))
              | TyApp (loc, _, _) -> error loc "invalid type name"
              | TyCls (_, i) -> (true, (ident i))
              | t -> error (loc_of_ctyp t) "invalid type"
            let rec ty_var_list_of_ctyp =
              function
              | Ast.TyApp (_, t1, t2) ->
                  (ty_var_list_of_ctyp t1) @ (ty_var_list_of_ctyp t2)
              | Ast.TyQuo (_, s) -> [ s ]
              | _ -> assert false
            let rec ctyp =
              function
              | TyId (loc, i) ->
                  let li = long_type_ident i
                  in mktyp loc (Ptyp_constr (li, []))
              | TyAli (loc, t1, t2) ->
                  let (t, i) =
                    (match (t1, t2) with
                     | (t, TyQuo (_, s)) -> (t, s)
                     | (TyQuo (_, s), t) -> (t, s)
                     | _ -> error loc "invalid alias type")
                  in mktyp loc (Ptyp_alias (ctyp t, i))
              | TyAny loc -> mktyp loc Ptyp_any
              | (TyApp (loc, _, _) as f) ->
                  let (f, al) = ctyp_fa [] f in
                  let (is_cls, li) = ctyp_long_id f
                  in
                    if is_cls
                    then mktyp loc (Ptyp_class (li, List.map ctyp al, []))
                    else mktyp loc (Ptyp_constr (li, List.map ctyp al))
              | TyArr (loc, (TyLab (_, lab, t1)), t2) ->
                  mktyp loc (Ptyp_arrow (lab, ctyp t1, ctyp t2))
              | TyArr (loc, (TyOlb (loc1, lab, t1)), t2) ->
                  let t1 =
                    TyApp (loc1, Ast.TyId (loc1, Ast.IdLid (loc1, "option")),
                      t1)
                  in mktyp loc (Ptyp_arrow ("?" ^ lab, ctyp t1, ctyp t2))
              | TyArr (loc, t1, t2) ->
                  mktyp loc (Ptyp_arrow ("", ctyp t1, ctyp t2))
              | Ast.TyObj (loc, (Ast.TyNil _), Ast.BFalse) ->
                  mktyp loc (Ptyp_object [])
              | Ast.TyObj (loc, (Ast.TyNil _), Ast.BTrue) ->
                  mktyp loc (Ptyp_object [ mkfield loc Pfield_var ])
              | Ast.TyObj (loc, fl, Ast.BFalse) ->
                  mktyp loc (Ptyp_object (meth_list fl []))
              | Ast.TyObj (loc, fl, Ast.BTrue) ->
                  mktyp loc
                    (Ptyp_object (meth_list fl [ mkfield loc Pfield_var ]))
              | TyCls (loc, id) -> mktyp loc (Ptyp_class (ident id, [], []))
              | TyLab (loc, _, _) ->
                  error loc "labelled type not allowed here"
              | TyMan (loc, _, _) ->
                  error loc "manifest type not allowed here"
              | TyOlb (loc, _, _) ->
                  error loc "labelled type not allowed here"
              | TyPol (loc, t1, t2) ->
                  mktyp loc (Ptyp_poly (ty_var_list_of_ctyp t1, ctyp t2))
              | TyQuo (loc, s) -> mktyp loc (Ptyp_var s)
              | TyRec (loc, _) -> error loc "record type not allowed here"
              | TySum (loc, _) -> error loc "sum type not allowed here"
              | TyPrv (loc, _) -> error loc "private type not allowed here"
              | TyMut (loc, _) -> error loc "mutable type not allowed here"
              | TyOr (loc, _, _) ->
                  error loc "type1 | type2 not allowed here"
              | TyAnd (loc, _, _) ->
                  error loc "type1 and type2 not allowed here"
              | TyOf (loc, _, _) ->
                  error loc "type1 of type2 not allowed here"
              | TyCol (loc, _, _) ->
                  error loc "type1 : type2 not allowed here"
              | TySem (loc, _, _) ->
                  error loc "type1 ; type2 not allowed here"
              | Ast.TyTup (loc, (Ast.TySta (_, t1, t2))) ->
                  mktyp loc
                    (Ptyp_tuple
                       (List.map ctyp (list_of_ctyp t1 (list_of_ctyp t2 []))))
              | Ast.TyVrnEq (loc, t) ->
                  mktyp loc (Ptyp_variant (row_field t, true, None))
              | Ast.TyVrnSup (loc, t) ->
                  mktyp loc (Ptyp_variant (row_field t, false, None))
              | Ast.TyVrnInf (loc, t) ->
                  mktyp loc (Ptyp_variant (row_field t, true, Some []))
              | Ast.TyVrnInfSup (loc, t, t') ->
                  mktyp loc
                    (Ptyp_variant (row_field t, true, Some (name_tags t')))
              | TyAnt (loc, _) -> error loc "antiquotation not allowed here"
              | TyOfAmp (_, _, _) | TyAmp (_, _, _) | TySta (_, _, _) |
                  TyCom (_, _, _) | TyVrn (_, _) | TyQuM (_, _) |
                  TyQuP (_, _) | TyDcl (_, _, _, _, _) |
                  TyObj (_, _, (BAnt _)) | TyNil _ | TyTup (_, _) ->
                  assert false
            and row_field =
              function
              | Ast.TyVrn (_, i) -> [ Rtag (i, true, []) ]
              | Ast.TyOfAmp (_, (Ast.TyVrn (_, i)), t) ->
                  [ Rtag (i, true, List.map ctyp (list_of_ctyp t [])) ]
              | Ast.TyOf (_, (Ast.TyVrn (_, i)), t) ->
                  [ Rtag (i, false, List.map ctyp (list_of_ctyp t [])) ]
              | Ast.TyOr (_, t1, t2) -> (row_field t1) @ (row_field t2)
              | t -> [ Rinherit (ctyp t) ]
            and name_tags =
              function
              | Ast.TyApp (_, t1, t2) -> (name_tags t1) @ (name_tags t2)
              | Ast.TyVrn (_, s) -> [ s ]
              | _ -> assert false
            and meth_list fl acc =
              match fl with
              | Ast.TySem (_, t1, t2) -> meth_list t1 (meth_list t2 acc)
              | Ast.TyCol (loc, (Ast.TyId (_, (Ast.IdLid (_, lab)))), t) ->
                  (mkfield loc (Pfield (lab, mkpolytype (ctyp t)))) :: acc
              | _ -> assert false
            let mktype loc tl cl tk tm =
              let (params, variance) = List.split tl
              in
                {
                  
                  ptype_params = params;
                  ptype_cstrs = cl;
                  ptype_kind = tk;
                  ptype_manifest = tm;
                  ptype_loc = mkloc loc;
                  ptype_variance = variance;
                }
            let mkprivate' m = if m then Private else Public
            let mkprivate m = mkprivate' (mb2b m)
            let mktrecord =
              function
              | Ast.TyCol (loc, (Ast.TyId (_, (Ast.IdLid (_, s)))),
                  (Ast.TyMut (_, t))) ->
                  (s, Mutable, (mkpolytype (ctyp t)), (mkloc loc))
              | Ast.TyCol (loc, (Ast.TyId (_, (Ast.IdLid (_, s)))), t) ->
                  (s, Immutable, (mkpolytype (ctyp t)), (mkloc loc))
              | _ -> assert false
            let mkvariant =
              function
              | Ast.TyId (loc, (Ast.IdUid (_, s))) ->
                  ((conv_con s), [], (mkloc loc))
              | Ast.TyOf (loc, (Ast.TyId (_, (Ast.IdUid (_, s)))), t) ->
                  ((conv_con s), (List.map ctyp (list_of_ctyp t [])),
                   (mkloc loc))
              | _ -> assert false
            let rec type_decl tl cl loc m pflag =
              function
              | TyMan (_, t1, t2) ->
                  type_decl tl cl loc (Some (ctyp t1)) pflag t2
              | TyPrv (_, t) -> type_decl tl cl loc m true t
              | TyRec (_, t) ->
                  mktype loc tl cl
                    (Ptype_record (List.map mktrecord (list_of_ctyp t []),
                       mkprivate' pflag))
                    m
              | TySum (_, t) ->
                  mktype loc tl cl
                    (Ptype_variant (List.map mkvariant (list_of_ctyp t []),
                       mkprivate' pflag))
                    m
              | t ->
                  if m <> None
                  then
                    error loc "only one manifest type allowed by definition"
                  else
                    (let m =
                       match t with
                       | TyQuo (_, s) ->
                           if List.mem_assoc s tl
                           then Some (ctyp t)
                           else None
                       | _ -> Some (ctyp t) in
                     let k = if pflag then Ptype_private else Ptype_abstract
                     in mktype loc tl cl k m)
            let type_decl tl cl t =
              type_decl tl cl (loc_of_ctyp t) None false t
            let mkvalue_desc t p = {  pval_type = ctyp t; pval_prim = p; }
            let mkmutable m = if mb2b m then Mutable else Immutable
            let paolab lab p =
              match (lab, p) with
              | ("",
                 (Ast.PaId (_, (Ast.IdLid (_, i))) |
                    Ast.PaTyc (_, (Ast.PaId (_, (Ast.IdLid (_, i)))), _)))
                  -> i
              | ("", p) -> error (loc_of_patt p) "bad ast in label"
              | _ -> lab
            let opt_private_ctyp =
              function
              | Ast.TyPrv (_, t) -> (Ptype_private, (ctyp t))
              | t -> (Ptype_abstract, (ctyp t))
            let rec type_parameters t acc =
              match t with
              | Ast.TyApp (_, t1, t2) ->
                  type_parameters t1 (type_parameters t2 acc)
              | Ast.TyQuP (_, s) -> (s, (true, false)) :: acc
              | Ast.TyQuM (_, s) -> (s, (false, true)) :: acc
              | Ast.TyQuo (_, s) -> (s, (false, false)) :: acc
              | _ -> assert false
            let rec class_parameters t acc =
              match t with
              | Ast.TyCom (_, t1, t2) ->
                  class_parameters t1 (class_parameters t2 acc)
              | Ast.TyQuP (_, s) -> (s, (true, false)) :: acc
              | Ast.TyQuM (_, s) -> (s, (false, true)) :: acc
              | Ast.TyQuo (_, s) -> (s, (false, false)) :: acc
              | _ -> assert false
            let rec type_parameters_and_type_name t acc =
              match t with
              | Ast.TyApp (_, t1, t2) ->
                  type_parameters_and_type_name t1 (type_parameters t2 acc)
              | Ast.TyId (_, i) -> ((ident i), acc)
              | _ -> assert false
            let rec mkwithc wc acc =
              match wc with
              | WcNil _ -> acc
              | WcTyp (loc, id_tpl, ct) ->
                  let (id, tpl) = type_parameters_and_type_name id_tpl [] in
                  let (params, variance) = List.split tpl in
                  let (kind, ct) = opt_private_ctyp ct
                  in
                    (id,
                     (Pwith_type
                        {
                          
                          ptype_params = params;
                          ptype_cstrs = [];
                          ptype_kind = kind;
                          ptype_manifest = Some ct;
                          ptype_loc = mkloc loc;
                          ptype_variance = variance;
                        })) ::
                      acc
              | WcMod (_, i1, i2) ->
                  ((long_uident i1), (Pwith_module (long_uident i2))) :: acc
              | Ast.WcAnd (_, wc1, wc2) -> mkwithc wc1 (mkwithc wc2 acc)
              | Ast.WcAnt (loc, _) ->
                  error loc "bad with constraint (antiquotation)"
            let rec patt_fa al =
              function
              | PaApp (_, f, a) -> patt_fa (a :: al) f
              | f -> (f, al)
            let rec deep_mkrangepat loc c1 c2 =
              if c1 = c2
              then mkghpat loc (Ppat_constant (Const_char c1))
              else
                mkghpat loc
                  (Ppat_or (mkghpat loc (Ppat_constant (Const_char c1)),
                     deep_mkrangepat loc (Char.chr ((Char.code c1) + 1)) c2))
            let rec mkrangepat loc c1 c2 =
              if c1 > c2
              then mkrangepat loc c2 c1
              else
                if c1 = c2
                then mkpat loc (Ppat_constant (Const_char c1))
                else
                  mkpat loc
                    (Ppat_or (mkghpat loc (Ppat_constant (Const_char c1)),
                       deep_mkrangepat loc (Char.chr ((Char.code c1) + 1)) c2))
            let rec patt =
              function
              | Ast.PaId (loc, (Ast.IdLid (_, s))) -> mkpat loc (Ppat_var s)
              | Ast.PaId (loc, i) ->
                  let p =
                    Ppat_construct (long_uident ~conv_con i, None,
                      constructors_arity ())
                  in mkpat loc p
              | PaAli (loc, p1, p2) ->
                  let (p, i) =
                    (match (p1, p2) with
                     | (p, Ast.PaId (_, (Ast.IdLid (_, s)))) -> (p, s)
                     | (Ast.PaId (_, (Ast.IdLid (_, s))), p) -> (p, s)
                     | _ -> error loc "invalid alias pattern")
                  in mkpat loc (Ppat_alias (patt p, i))
              | PaAnt (loc, _) -> error loc "antiquotation not allowed here"
              | PaAny loc -> mkpat loc Ppat_any
              | Ast.PaApp (loc, (Ast.PaId (_, (Ast.IdUid (_, s)))),
                  (Ast.PaTup (_, (Ast.PaAny loc_any)))) ->
                  mkpat loc
                    (Ppat_construct (lident (conv_con s),
                       Some (mkpat loc_any Ppat_any), false))
              | (PaApp (loc, _, _) as f) ->
                  let (f, al) = patt_fa [] f in
                  let al = List.map patt al
                  in
                    (match (patt f).ppat_desc with
                     | Ppat_construct (li, None, _) ->
                         if constructors_arity ()
                         then
                           mkpat loc
                             (Ppat_construct (li,
                                Some (mkpat loc (Ppat_tuple al)), true))
                         else
                           (let a =
                              match al with
                              | [ a ] -> a
                              | _ -> mkpat loc (Ppat_tuple al)
                            in mkpat loc (Ppat_construct (li, Some a, false)))
                     | Ppat_variant (s, None) ->
                         let a =
                           if constructors_arity ()
                           then mkpat loc (Ppat_tuple al)
                           else
                             (match al with
                              | [ a ] -> a
                              | _ -> mkpat loc (Ppat_tuple al))
                         in mkpat loc (Ppat_variant (s, Some a))
                     | _ ->
                         error (loc_of_patt f)
                           "this is not a constructor, it cannot be applied in a pattern")
              | PaArr (loc, p) ->
                  mkpat loc (Ppat_array (List.map patt (list_of_patt p [])))
              | PaChr (loc, s) ->
                  mkpat loc
                    (Ppat_constant (Const_char (char_of_char_token loc s)))
              | PaInt (loc, s) ->
                  let i =
                    (try int_of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type int")
                  in mkpat loc (Ppat_constant (Const_int i))
              | PaInt32 (loc, s) ->
                  let i32 =
                    (try Int32.of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type int32")
                  in mkpat loc (Ppat_constant (Const_int32 i32))
              | PaInt64 (loc, s) ->
                  let i64 =
                    (try Int64.of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type int64")
                  in mkpat loc (Ppat_constant (Const_int64 i64))
              | PaNativeInt (loc, s) ->
                  let nati =
                    (try Nativeint.of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type nativeint")
                  in mkpat loc (Ppat_constant (Const_nativeint nati))
              | PaFlo (loc, s) -> mkpat loc (Ppat_constant (Const_float s))
              | PaLab (loc, _, _) ->
                  error loc "labeled pattern not allowed here"
              | PaOlb (loc, _, _) | PaOlbi (loc, _, _, _) ->
                  error loc "labeled pattern not allowed here"
              | PaOrp (loc, p1, p2) -> mkpat loc (Ppat_or (patt p1, patt p2))
              | PaRng (loc, p1, p2) ->
                  (match (p1, p2) with
                   | (PaChr (loc1, c1), PaChr (loc2, c2)) ->
                       let c1 = char_of_char_token loc1 c1 in
                       let c2 = char_of_char_token loc2 c2
                       in mkrangepat loc c1 c2
                   | _ ->
                       error loc "range pattern allowed only for characters")
              | PaRec (loc, p) ->
                  mkpat loc
                    (Ppat_record (List.map mklabpat (list_of_patt p [])))
              | PaStr (loc, s) ->
                  mkpat loc
                    (Ppat_constant
                       (Const_string (string_of_string_token loc s)))
              | Ast.PaTup (loc, (Ast.PaCom (_, p1, p2))) ->
                  mkpat loc
                    (Ppat_tuple
                       (List.map patt (list_of_patt p1 (list_of_patt p2 []))))
              | Ast.PaTup (loc, _) -> error loc "singleton tuple pattern"
              | PaTyc (loc, p, t) ->
                  mkpat loc (Ppat_constraint (patt p, ctyp t))
              | PaTyp (loc, i) -> mkpat loc (Ppat_type (long_type_ident i))
              | PaVrn (loc, s) -> mkpat loc (Ppat_variant (s, None))
              | (PaEq (_, _, _) | PaSem (_, _, _) | PaCom (_, _, _) | PaNil _
                 as p) -> error (loc_of_patt p) "invalid pattern"
            and mklabpat =
              function
              | Ast.PaEq (_, (Ast.PaId (_, i)), p) ->
                  ((ident ~conv_lid: conv_lab i), (patt p))
              | p -> error (loc_of_patt p) "invalid pattern"
            let rec expr_fa al =
              function
              | ExApp (_, f, a) -> expr_fa (a :: al) f
              | f -> (f, al)
            let rec class_expr_fa al =
              function
              | CeApp (_, ce, a) -> class_expr_fa (a :: al) ce
              | ce -> (ce, al)
            let rec sep_expr_acc l =
              function
              | ExAcc (_, e1, e2) -> sep_expr_acc (sep_expr_acc l e2) e1
              | (Ast.ExId (loc, (Ast.IdUid (_, s))) as e) ->
                  (match l with
                   | [] -> [ (loc, [], e) ]
                   | (loc', sl, e) :: l ->
                       ((Loc.merge loc loc'), (s :: sl), e) :: l)
              | Ast.ExId (_, ((Ast.IdAcc (_, _, _) as i))) ->
                  let rec normalize_acc =
                    (function
                     | Ast.IdAcc (_loc, i1, i2) ->
                         Ast.ExAcc (_loc, normalize_acc i1, normalize_acc i2)
                     | Ast.IdApp (_loc, i1, i2) ->
                         Ast.ExApp (_loc, normalize_acc i1, normalize_acc i2)
                     | (Ast.IdAnt (_loc, _) | Ast.IdUid (_loc, _) |
                          Ast.IdLid (_loc, _)
                        as i) -> Ast.ExId (_loc, i))
                  in sep_expr_acc l (normalize_acc i)
              | e -> ((loc_of_expr e), [], e) :: l
            let list_of_opt_ctyp ot acc =
              match ot with | Ast.TyNil _ -> acc | t -> list_of_ctyp t acc
            let rec expr =
              function
              | Ast.ExAcc (loc, x, (Ast.ExId (_, (Ast.IdLid (_, "val"))))) ->
                  mkexp loc
                    (Pexp_apply (mkexp loc (Pexp_ident (Lident "!")),
                       [ ("", (expr x)) ]))
              | (ExAcc (loc, _, _) | Ast.ExId (loc, (Ast.IdAcc (_, _, _))) as
                 e) ->
                  let (e, l) =
                    (match sep_expr_acc [] e with
                     | (loc, ml, Ast.ExId (_, (Ast.IdUid (_, s)))) :: l ->
                         let ca = constructors_arity ()
                         in
                           ((mkexp loc (Pexp_construct (mkli s ml, None, ca))),
                            l)
                     | (loc, ml, Ast.ExId (_, (Ast.IdLid (_, s)))) :: l ->
                         ((mkexp loc (Pexp_ident (mkli s ml))), l)
                     | (_, [], e) :: l -> ((expr e), l)
                     | _ -> error loc "bad ast in expression") in
                  let (_, e) =
                    List.fold_left
                      (fun (loc_bp, e1) (loc_ep, ml, e2) ->
                         match e2 with
                         | Ast.ExId (_, (Ast.IdLid (_, s))) ->
                             let loc = Loc.merge loc_bp loc_ep
                             in
                               (loc,
                                (mkexp loc
                                   (Pexp_field (e1, mkli (conv_lab s) ml))))
                         | _ ->
                             error (loc_of_expr e2)
                               "lowercase identifier expected")
                      (loc, e) l
                  in e
              | ExAnt (loc, _) -> error loc "antiquotation not allowed here"
              | (ExApp (loc, _, _) as f) ->
                  let (f, al) = expr_fa [] f in
                  let al = List.map label_expr al
                  in
                    (match (expr f).pexp_desc with
                     | Pexp_construct (li, None, _) ->
                         let al = List.map snd al
                         in
                           if constructors_arity ()
                           then
                             mkexp loc
                               (Pexp_construct (li,
                                  Some (mkexp loc (Pexp_tuple al)), true))
                           else
                             (let a =
                                match al with
                                | [ a ] -> a
                                | _ -> mkexp loc (Pexp_tuple al)
                              in
                                mkexp loc
                                  (Pexp_construct (li, Some a, false)))
                     | Pexp_variant (s, None) ->
                         let al = List.map snd al in
                         let a =
                           if constructors_arity ()
                           then mkexp loc (Pexp_tuple al)
                           else
                             (match al with
                              | [ a ] -> a
                              | _ -> mkexp loc (Pexp_tuple al))
                         in mkexp loc (Pexp_variant (s, Some a))
                     | _ -> mkexp loc (Pexp_apply (expr f, al)))
              | ExAre (loc, e1, e2) ->
                  mkexp loc
                    (Pexp_apply
                       (mkexp loc (Pexp_ident (array_function "Array" "get")),
                       [ ("", (expr e1)); ("", (expr e2)) ]))
              | ExArr (loc, e) ->
                  mkexp loc (Pexp_array (List.map expr (list_of_expr e [])))
              | ExAsf loc -> mkexp loc Pexp_assertfalse
              | ExAss (loc, e, v) ->
                  let e =
                    (match e with
                     | Ast.ExAcc (loc, x,
                         (Ast.ExId (_, (Ast.IdLid (_, "val"))))) ->
                         Pexp_apply (mkexp loc (Pexp_ident (Lident ":=")),
                           [ ("", (expr x)); ("", (expr v)) ])
                     | ExAcc (loc, _, _) ->
                         (match (expr e).pexp_desc with
                          | Pexp_field (e, lab) ->
                              Pexp_setfield (e, lab, expr v)
                          | _ -> error loc "bad record access")
                     | ExAre (_, e1, e2) ->
                         Pexp_apply
                           (mkexp loc
                              (Pexp_ident (array_function "Array" "set")),
                           [ ("", (expr e1)); ("", (expr e2)); ("", (expr v)) ])
                     | Ast.ExId (_, (Ast.IdLid (_, lab))) ->
                         Pexp_setinstvar (lab, expr v)
                     | ExSte (_, e1, e2) ->
                         Pexp_apply
                           (mkexp loc
                              (Pexp_ident (array_function "String" "set")),
                           [ ("", (expr e1)); ("", (expr e2)); ("", (expr v)) ])
                     | _ -> error loc "bad left part of assignment")
                  in mkexp loc e
              | ExAsr (loc, e) -> mkexp loc (Pexp_assert (expr e))
              | ExChr (loc, s) ->
                  mkexp loc
                    (Pexp_constant (Const_char (char_of_char_token loc s)))
              | ExCoe (loc, e, t1, t2) ->
                  let t1 =
                    (match t1 with | Ast.TyNil _ -> None | t -> Some (ctyp t))
                  in mkexp loc (Pexp_constraint (expr e, t1, Some (ctyp t2)))
              | ExFlo (loc, s) -> mkexp loc (Pexp_constant (Const_float s))
              | ExFor (loc, i, e1, e2, df, el) ->
                  let e3 = ExSeq (loc, el) in
                  let df = if mb2b df then Upto else Downto
                  in mkexp loc (Pexp_for (i, expr e1, expr e2, df, expr e3))
              | Ast.ExFun (loc, (Ast.McArr (_, (PaLab (_, lab, po)), w, e)))
                  ->
                  mkexp loc
                    (Pexp_function (lab, None,
                       [ ((patt_of_lab loc lab po), (when_expr e w)) ]))
              | Ast.ExFun (loc,
                  (Ast.McArr (_, (PaOlbi (_, lab, p, e1)), w, e2))) ->
                  let lab = paolab lab p
                  in
                    mkexp loc
                      (Pexp_function ("?" ^ lab, Some (expr e1),
                         [ ((patt p), (when_expr e2 w)) ]))
              | Ast.ExFun (loc, (Ast.McArr (_, (PaOlb (_, lab, p)), w, e)))
                  ->
                  let lab = paolab lab p
                  in
                    mkexp loc
                      (Pexp_function ("?" ^ lab, None,
                         [ ((patt_of_lab loc lab p), (when_expr e w)) ]))
              | ExFun (loc, a) ->
                  mkexp loc (Pexp_function ("", None, match_case a []))
              | ExIfe (loc, e1, e2, e3) ->
                  mkexp loc
                    (Pexp_ifthenelse (expr e1, expr e2, Some (expr e3)))
              | ExInt (loc, s) ->
                  let i =
                    (try int_of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type int")
                  in mkexp loc (Pexp_constant (Const_int i))
              | ExInt32 (loc, s) ->
                  let i32 =
                    (try Int32.of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type int32")
                  in mkexp loc (Pexp_constant (Const_int32 i32))
              | ExInt64 (loc, s) ->
                  let i64 =
                    (try Int64.of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type int64")
                  in mkexp loc (Pexp_constant (Const_int64 i64))
              | ExNativeInt (loc, s) ->
                  let nati =
                    (try Nativeint.of_string s
                     with
                     | Failure _ ->
                         error loc
                           "Integer literal exceeds the range of representable integers of type nativeint")
                  in mkexp loc (Pexp_constant (Const_nativeint nati))
              | ExLab (loc, _, _) ->
                  error loc "labeled expression not allowed here"
              | ExLaz (loc, e) -> mkexp loc (Pexp_lazy (expr e))
              | ExLet (loc, rf, bi, e) ->
                  mkexp loc (Pexp_let (mkrf rf, binding bi [], expr e))
              | ExLmd (loc, i, me, e) ->
                  mkexp loc (Pexp_letmodule (i, module_expr me, expr e))
              | ExMat (loc, e, a) ->
                  mkexp loc (Pexp_match (expr e, match_case a []))
              | ExNew (loc, id) -> mkexp loc (Pexp_new (long_type_ident id))
              | ExObj (loc, po, cfl) ->
                  let p =
                    (match po with | Ast.PaNil _ -> Ast.PaAny loc | p -> p) in
                  let cil = class_str_item cfl []
                  in mkexp loc (Pexp_object (((patt p), cil)))
              | ExOlb (loc, _, _) ->
                  error loc "labeled expression not allowed here"
              | ExOvr (loc, iel) ->
                  mkexp loc (Pexp_override (mkideexp iel []))
              | ExRec (loc, lel, eo) ->
                  (match lel with
                   | Ast.BiNil _ -> error loc "empty record"
                   | _ ->
                       let eo =
                         (match eo with
                          | Ast.ExNil _ -> None
                          | e -> Some (expr e))
                       in mkexp loc (Pexp_record (mklabexp lel [], eo)))
              | ExSeq (_loc, e) ->
                  let rec loop =
                    (function
                     | [] -> expr (Ast.ExId (_loc, Ast.IdUid (_loc, "()")))
                     | [ e ] -> expr e
                     | e :: el ->
                         let _loc = Loc.merge (loc_of_expr e) _loc
                         in mkexp _loc (Pexp_sequence (expr e, loop el)))
                  in loop (list_of_expr e [])
              | ExSnd (loc, e, s) -> mkexp loc (Pexp_send (expr e, s))
              | ExSte (loc, e1, e2) ->
                  mkexp loc
                    (Pexp_apply
                       (mkexp loc
                          (Pexp_ident (array_function "String" "get")),
                       [ ("", (expr e1)); ("", (expr e2)) ]))
              | ExStr (loc, s) ->
                  mkexp loc
                    (Pexp_constant
                       (Const_string (string_of_string_token loc s)))
              | ExTry (loc, e, a) ->
                  mkexp loc (Pexp_try (expr e, match_case a []))
              | Ast.ExTup (loc, (Ast.ExCom (_, e1, e2))) ->
                  mkexp loc
                    (Pexp_tuple
                       (List.map expr (list_of_expr e1 (list_of_expr e2 []))))
              | Ast.ExTup (loc, _) -> error loc "singleton tuple"
              | ExTyc (loc, e, t) ->
                  mkexp loc (Pexp_constraint (expr e, Some (ctyp t), None))
              | Ast.ExId (loc, (Ast.IdUid (_, "()"))) ->
                  mkexp loc (Pexp_construct (lident "()", None, true))
              | Ast.ExId (loc, (Ast.IdLid (_, s))) ->
                  mkexp loc (Pexp_ident (lident s))
              | Ast.ExId (loc, (Ast.IdUid (_, s))) ->
                  mkexp loc
                    (Pexp_construct (lident (conv_con s), None, true))
              | ExVrn (loc, s) -> mkexp loc (Pexp_variant (s, None))
              | ExWhi (loc, e1, el) ->
                  let e2 = ExSeq (loc, el)
                  in mkexp loc (Pexp_while (expr e1, expr e2))
              | Ast.ExCom (loc, _, _) ->
                  error loc "expr, expr: not allowed here"
              | Ast.ExSem (loc, _, _) ->
                  error loc
                    "expr; expr: not allowed here, use do {...} or [|...|] to surround them"
              | (ExId (_, _) | ExNil _ as e) ->
                  error (loc_of_expr e) "invalid expr"
            and patt_of_lab _loc lab =
              function
              | Ast.PaNil _ -> patt (Ast.PaId (_loc, Ast.IdLid (_loc, lab)))
              | p -> patt p
            and expr_of_lab _loc lab =
              function
              | Ast.ExNil _ -> expr (Ast.ExId (_loc, Ast.IdLid (_loc, lab)))
              | e -> expr e
            and label_expr =
              function
              | ExLab (loc, lab, eo) -> (lab, (expr_of_lab loc lab eo))
              | ExOlb (loc, lab, eo) ->
                  (("?" ^ lab), (expr_of_lab loc lab eo))
              | e -> ("", (expr e))
            and binding x acc =
              match x with
              | Ast.BiAnd (_, x, y) | Ast.BiSem (_, x, y) ->
                  binding x (binding y acc)
              | Ast.BiEq (_, p, e) -> ((patt p), (expr e)) :: acc
              | Ast.BiNil _ -> acc
              | _ -> assert false
            and match_case x acc =
              match x with
              | Ast.McOr (_, x, y) -> match_case x (match_case y acc)
              | Ast.McArr (_, p, w, e) -> ((patt p), (when_expr e w)) :: acc
              | Ast.McNil _ -> acc
              | _ -> assert false
            and when_expr e w =
              match w with
              | Ast.ExNil _ -> expr e
              | w -> mkexp (loc_of_expr w) (Pexp_when (expr w, expr e))
            and mklabexp x acc =
              match x with
              | Ast.BiAnd (_, x, y) | Ast.BiSem (_, x, y) ->
                  mklabexp x (mklabexp y acc)
              | Ast.BiEq (_, (Ast.PaId (_, i)), e) ->
                  ((ident ~conv_lid: conv_lab i), (expr e)) :: acc
              | _ -> assert false
            and mkideexp x acc =
              match x with
              | Ast.BiAnd (_, x, y) | Ast.BiSem (_, x, y) ->
                  mkideexp x (mkideexp y acc)
              | Ast.BiEq (_, (Ast.PaId (_, (Ast.IdLid (_, s)))), e) ->
                  (s, (expr e)) :: acc
              | _ -> assert false
            and mktype_decl x acc =
              match x with
              | Ast.TyAnd (_, x, y) -> mktype_decl x (mktype_decl y acc)
              | Ast.TyDcl (_, c, tl, td, cl) ->
                  let cl =
                    List.map
                      (fun (t1, t2) ->
                         let loc =
                           Loc.merge (loc_of_ctyp t1) (loc_of_ctyp t2)
                         in ((ctyp t1), (ctyp t2), (mkloc loc)))
                      cl
                  in
                    (c,
                     (type_decl (List.fold_right type_parameters tl []) cl td)) ::
                      acc
              | _ -> assert false
            and module_type =
              function
              | MtId (loc, i) -> mkmty loc (Pmty_ident (long_uident i))
              | MtFun (loc, n, nt, mt) ->
                  mkmty loc
                    (Pmty_functor (n, module_type nt, module_type mt))
              | MtQuo (loc, _) ->
                  error loc "abstract module type not allowed here"
              | MtSig (loc, sl) ->
                  mkmty loc (Pmty_signature (sig_item sl []))
              | MtWit (loc, mt, wc) ->
                  mkmty loc (Pmty_with (module_type mt, mkwithc wc []))
              | Ast.MtAnt (_, _) -> assert false
            and sig_item s l =
              match s with
              | Ast.SgNil _ -> l
              | SgCls (loc, cd) ->
                  (mksig loc
                     (Psig_class
                        (List.map class_info_class_type
                           (list_of_class_type cd [])))) ::
                    l
              | SgClt (loc, ctd) ->
                  (mksig loc
                     (Psig_class_type
                        (List.map class_info_class_type
                           (list_of_class_type ctd [])))) ::
                    l
              | Ast.SgSem (_, sg1, sg2) -> sig_item sg1 (sig_item sg2 l)
              | SgDir (_, _, _) -> l
              | Ast.SgExc (loc, (Ast.TyId (_, (Ast.IdUid (_, s))))) ->
                  (mksig loc (Psig_exception (conv_con s, []))) :: l
              | Ast.SgExc (loc,
                  (Ast.TyOf (_, (Ast.TyId (_, (Ast.IdUid (_, s)))), t))) ->
                  (mksig loc
                     (Psig_exception (conv_con s,
                        List.map ctyp (list_of_ctyp t [])))) ::
                    l
              | SgExc (_, _) -> assert false
              | SgExt (loc, n, t, p) ->
                  (mksig loc (Psig_value (n, mkvalue_desc t [ p ]))) :: l
              | SgInc (loc, mt) ->
                  (mksig loc (Psig_include (module_type mt))) :: l
              | SgMod (loc, n, mt) ->
                  (mksig loc (Psig_module (n, module_type mt))) :: l
              | SgRecMod (loc, mb) ->
                  (mksig loc (Psig_recmodule (module_sig_binding mb []))) ::
                    l
              | SgMty (loc, n, mt) ->
                  let si =
                    (match mt with
                     | MtQuo (_, _) -> Pmodtype_abstract
                     | _ -> Pmodtype_manifest (module_type mt))
                  in (mksig loc (Psig_modtype (n, si))) :: l
              | SgOpn (loc, id) ->
                  (mksig loc (Psig_open (long_uident id))) :: l
              | SgTyp (loc, tdl) ->
                  (mksig loc (Psig_type (mktype_decl tdl []))) :: l
              | SgVal (loc, n, t) ->
                  (mksig loc (Psig_value (n, mkvalue_desc t []))) :: l
              | Ast.SgAnt (loc, _) -> error loc "antiquotation in sig_item"
            and module_sig_binding x acc =
              match x with
              | Ast.MbAnd (_, x, y) ->
                  module_sig_binding x (module_sig_binding y acc)
              | Ast.MbCol (_, s, mt) -> (s, (module_type mt)) :: acc
              | _ -> assert false
            and module_str_binding x acc =
              match x with
              | Ast.MbAnd (_, x, y) ->
                  module_str_binding x (module_str_binding y acc)
              | Ast.MbColEq (_, s, mt, me) ->
                  (s, (module_type mt), (module_expr me)) :: acc
              | _ -> assert false
            and module_expr =
              function
              | MeId (loc, i) -> mkmod loc (Pmod_ident (long_uident i))
              | MeApp (loc, me1, me2) ->
                  mkmod loc (Pmod_apply (module_expr me1, module_expr me2))
              | MeFun (loc, n, mt, me) ->
                  mkmod loc
                    (Pmod_functor (n, module_type mt, module_expr me))
              | MeStr (loc, sl) ->
                  mkmod loc (Pmod_structure (str_item sl []))
              | MeTyc (loc, me, mt) ->
                  mkmod loc
                    (Pmod_constraint (module_expr me, module_type mt))
              | Ast.MeAnt (loc, _) ->
                  error loc "antiquotation in module_expr"
            and str_item s l =
              match s with
              | Ast.StNil _ -> l
              | StCls (loc, cd) ->
                  (mkstr loc
                     (Pstr_class
                        (List.map class_info_class_expr
                           (list_of_class_expr cd [])))) ::
                    l
              | StClt (loc, ctd) ->
                  (mkstr loc
                     (Pstr_class_type
                        (List.map class_info_class_type
                           (list_of_class_type ctd [])))) ::
                    l
              | Ast.StSem (_, st1, st2) -> str_item st1 (str_item st2 l)
              | StDir (_, _, _) -> l
              | Ast.StExc (loc, (Ast.TyId (_, (Ast.IdUid (_, s)))), Ast.
                  ONone) ->
                  (mkstr loc (Pstr_exception (conv_con s, []))) :: l
              | Ast.StExc (loc,
                  (Ast.TyOf (_, (Ast.TyId (_, (Ast.IdUid (_, s)))), t)), Ast.
                  ONone) ->
                  (mkstr loc
                     (Pstr_exception (conv_con s,
                        List.map ctyp (list_of_ctyp t [])))) ::
                    l
              | Ast.StExc (loc, (Ast.TyId (_, (Ast.IdUid (_, s)))),
                  (Ast.OSome i)) ->
                  (mkstr loc (Pstr_exn_rebind (conv_con s, ident i))) :: l
              | StExc (_, _, _) -> assert false
              | StExp (loc, e) -> (mkstr loc (Pstr_eval (expr e))) :: l
              | StExt (loc, n, t, p) ->
                  (mkstr loc (Pstr_primitive (n, mkvalue_desc t [ p ]))) :: l
              | StInc (loc, me) ->
                  (mkstr loc (Pstr_include (module_expr me))) :: l
              | StMod (loc, n, me) ->
                  (mkstr loc (Pstr_module (n, module_expr me))) :: l
              | StRecMod (loc, mb) ->
                  (mkstr loc (Pstr_recmodule (module_str_binding mb []))) ::
                    l
              | StMty (loc, n, mt) ->
                  (mkstr loc (Pstr_modtype (n, module_type mt))) :: l
              | StOpn (loc, id) ->
                  (mkstr loc (Pstr_open (long_uident id))) :: l
              | StTyp (loc, tdl) ->
                  (mkstr loc (Pstr_type (mktype_decl tdl []))) :: l
              | StVal (loc, rf, bi) ->
                  (mkstr loc (Pstr_value (mkrf rf, binding bi []))) :: l
              | Ast.StAnt (loc, _) -> error loc "antiquotation in str_item"
            and class_type =
              function
              | CtCon (loc, Ast.BFalse, id, tl) ->
                  mkcty loc
                    (Pcty_constr (long_class_ident id,
                       List.map ctyp (list_of_opt_ctyp tl [])))
              | CtFun (loc, (TyLab (_, lab, t)), ct) ->
                  mkcty loc (Pcty_fun (lab, ctyp t, class_type ct))
              | CtFun (loc, (TyOlb (loc1, lab, t)), ct) ->
                  let t =
                    TyApp (loc1, Ast.TyId (loc1, Ast.IdLid (loc1, "option")),
                      t)
                  in mkcty loc (Pcty_fun ("?" ^ lab, ctyp t, class_type ct))
              | CtFun (loc, t, ct) ->
                  mkcty loc (Pcty_fun ("", ctyp t, class_type ct))
              | CtSig (loc, t_o, ctfl) ->
                  let t =
                    (match t_o with | Ast.TyNil _ -> Ast.TyAny loc | t -> t) in
                  let cil = class_sig_item ctfl []
                  in mkcty loc (Pcty_signature (((ctyp t), cil)))
              | CtCon (loc, _, _, _) ->
                  error loc "invalid virtual class inside a class type"
              | CtAnt (_, _) | CtEq (_, _, _) | CtCol (_, _, _) |
                  CtAnd (_, _, _) | CtNil _ -> assert false
            and class_info_class_expr ci =
              match ci with
              | CeEq (_, (CeCon (loc, vir, (IdLid (_, name)), params)), ce)
                  ->
                  let (loc_params, (params, variance)) =
                    (match params with
                     | Ast.TyNil _ -> (loc, ([], []))
                     | t ->
                         ((loc_of_ctyp t),
                          (List.split (class_parameters t []))))
                  in
                    {
                      
                      pci_virt = if mb2b vir then Virtual else Concrete;
                      pci_params = (params, (mkloc loc_params));
                      pci_name = name;
                      pci_expr = class_expr ce;
                      pci_loc = mkloc loc;
                      pci_variance = variance;
                    }
              | ce -> error (loc_of_class_expr ce) "bad class definition"
            and class_info_class_type ci =
              match ci with
              | CtEq (_, (CtCon (loc, vir, (IdLid (_, name)), params)), ct) |
                  CtCol (_, (CtCon (loc, vir, (IdLid (_, name)), params)),
                    ct)
                  ->
                  let (loc_params, (params, variance)) =
                    (match params with
                     | Ast.TyNil _ -> (loc, ([], []))
                     | t ->
                         ((loc_of_ctyp t),
                          (List.split (class_parameters t []))))
                  in
                    {
                      
                      pci_virt = if mb2b vir then Virtual else Concrete;
                      pci_params = (params, (mkloc loc_params));
                      pci_name = name;
                      pci_expr = class_type ct;
                      pci_loc = mkloc loc;
                      pci_variance = variance;
                    }
              | ct ->
                  error (loc_of_class_type ct)
                    "bad class/class type declaration/definition"
            and class_sig_item c l =
              match c with
              | Ast.CgNil _ -> l
              | CgCtr (loc, t1, t2) ->
                  (Pctf_cstr (((ctyp t1), (ctyp t2), (mkloc loc)))) :: l
              | Ast.CgSem (_, csg1, csg2) ->
                  class_sig_item csg1 (class_sig_item csg2 l)
              | CgInh (_, ct) -> (Pctf_inher (class_type ct)) :: l
              | CgMth (loc, s, pf, t) ->
                  (Pctf_meth
                     ((s, (mkprivate pf), (mkpolytype (ctyp t)), (mkloc loc)))) ::
                    l
              | CgVal (loc, s, b, v, t) ->
                  (Pctf_val
                     ((s, (mkmutable b), (mkvirtual v), (ctyp t),
                       (mkloc loc)))) ::
                    l
              | CgVir (loc, s, b, t) ->
                  (Pctf_virt
                     ((s, (mkprivate b), (mkpolytype (ctyp t)), (mkloc loc)))) ::
                    l
              | CgAnt (_, _) -> assert false
            and class_expr =
              function
              | (CeApp (loc, _, _) as c) ->
                  let (ce, el) = class_expr_fa [] c in
                  let el = List.map label_expr el
                  in mkpcl loc (Pcl_apply (class_expr ce, el))
              | CeCon (loc, Ast.BFalse, id, tl) ->
                  mkpcl loc
                    (Pcl_constr (long_class_ident id,
                       List.map ctyp (list_of_opt_ctyp tl [])))
              | CeFun (loc, (PaLab (_, lab, po)), ce) ->
                  mkpcl loc
                    (Pcl_fun (lab, None, patt_of_lab loc lab po,
                       class_expr ce))
              | CeFun (loc, (PaOlbi (_, lab, p, e)), ce) ->
                  let lab = paolab lab p
                  in
                    mkpcl loc
                      (Pcl_fun ("?" ^ lab, Some (expr e), patt p,
                         class_expr ce))
              | CeFun (loc, (PaOlb (_, lab, p)), ce) ->
                  let lab = paolab lab p
                  in
                    mkpcl loc
                      (Pcl_fun ("?" ^ lab, None, patt_of_lab loc lab p,
                         class_expr ce))
              | CeFun (loc, p, ce) ->
                  mkpcl loc (Pcl_fun ("", None, patt p, class_expr ce))
              | CeLet (loc, rf, bi, ce) ->
                  mkpcl loc (Pcl_let (mkrf rf, binding bi [], class_expr ce))
              | CeStr (loc, po, cfl) ->
                  let p =
                    (match po with | Ast.PaNil _ -> Ast.PaAny loc | p -> p) in
                  let cil = class_str_item cfl []
                  in mkpcl loc (Pcl_structure (((patt p), cil)))
              | CeTyc (loc, ce, ct) ->
                  mkpcl loc (Pcl_constraint (class_expr ce, class_type ct))
              | CeCon (loc, _, _, _) ->
                  error loc "invalid virtual class inside a class expression"
              | CeAnt (_, _) | CeEq (_, _, _) | CeAnd (_, _, _) | CeNil _ ->
                  assert false
            and class_str_item c l =
              match c with
              | CrNil _ -> l
              | CrCtr (loc, t1, t2) ->
                  (Pcf_cstr (((ctyp t1), (ctyp t2), (mkloc loc)))) :: l
              | Ast.CrSem (_, cst1, cst2) ->
                  class_str_item cst1 (class_str_item cst2 l)
              | CrInh (_, ce, "") -> (Pcf_inher (class_expr ce, None)) :: l
              | CrInh (_, ce, pb) ->
                  (Pcf_inher (class_expr ce, Some pb)) :: l
              | CrIni (_, e) -> (Pcf_init (expr e)) :: l
              | CrMth (loc, s, b, e, t) ->
                  let t =
                    (match t with
                     | Ast.TyNil _ -> None
                     | t -> Some (mkpolytype (ctyp t))) in
                  let e = mkexp loc (Pexp_poly (expr e, t))
                  in (Pcf_meth ((s, (mkprivate b), e, (mkloc loc)))) :: l
              | CrVal (loc, s, b, e) ->
                  (Pcf_val ((s, (mkmutable b), (expr e), (mkloc loc)))) :: l
              | CrVir (loc, s, b, t) ->
                  (Pcf_virt
                     ((s, (mkprivate b), (mkpolytype (ctyp t)), (mkloc loc)))) ::
                    l
              | CrVvr (loc, s, b, t) ->
                  (Pcf_valvirt ((s, (mkmutable b), (ctyp t), (mkloc loc)))) ::
                    l
              | CrAnt (_, _) -> assert false
            let sig_item ast = sig_item ast []
            let str_item ast = str_item ast []
            let directive =
              function
              | Ast.ExNil _ -> Pdir_none
              | ExStr (_, s) -> Pdir_string s
              | ExInt (_, i) -> Pdir_int (int_of_string i)
              | Ast.ExId (_, (Ast.IdUid (_, "True"))) -> Pdir_bool true
              | Ast.ExId (_, (Ast.IdUid (_, "False"))) -> Pdir_bool false
              | e -> Pdir_ident (ident (ident_of_expr e))
            let phrase =
              function
              | StDir (_, d, dp) -> Ptop_dir (d, directive dp)
              | si -> Ptop_def (str_item si)
          end
      end
    module CleanAst =
      struct
        module Make (Ast : Sig.Camlp4Ast) =
          struct
            class clean_ast =
              object (self)
                inherit Ast.map as super
                method with_constr =
                  function
                  | Ast.WcAnd (_, (Ast.WcNil _), wc) |
                      Ast.WcAnd (_, wc, (Ast.WcNil _)) -> self#with_constr wc
                  | wc -> super#with_constr wc
                method expr =
                  function
                  | Ast.ExLet (_, _, (Ast.BiNil _), e) |
                      Ast.ExRec (_, (Ast.BiNil _), e) |
                      Ast.ExCom (_, (Ast.ExNil _), e) |
                      Ast.ExCom (_, e, (Ast.ExNil _)) |
                      Ast.ExSem (_, (Ast.ExNil _), e) |
                      Ast.ExSem (_, e, (Ast.ExNil _)) -> self#expr e
                  | e -> super#expr e
                method patt =
                  function
                  | Ast.PaAli (_, p, (Ast.PaNil _)) |
                      Ast.PaOrp (_, (Ast.PaNil _), p) |
                      Ast.PaOrp (_, p, (Ast.PaNil _)) |
                      Ast.PaCom (_, (Ast.PaNil _), p) |
                      Ast.PaCom (_, p, (Ast.PaNil _)) |
                      Ast.PaSem (_, (Ast.PaNil _), p) |
                      Ast.PaSem (_, p, (Ast.PaNil _)) -> self#patt p
                  | p -> super#patt p
                method match_case =
                  function
                  | Ast.McOr (_, (Ast.McNil _), mc) |
                      Ast.McOr (_, mc, (Ast.McNil _)) -> self#match_case mc
                  | mc -> super#match_case mc
                method binding =
                  function
                  | Ast.BiAnd (_, (Ast.BiNil _), bi) |
                      Ast.BiAnd (_, bi, (Ast.BiNil _)) |
                      Ast.BiSem (_, (Ast.BiNil _), bi) |
                      Ast.BiSem (_, bi, (Ast.BiNil _)) -> self#binding bi
                  | bi -> super#binding bi
                method module_binding =
                  function
                  | Ast.MbAnd (_, (Ast.MbNil _), mb) |
                      Ast.MbAnd (_, mb, (Ast.MbNil _)) ->
                      self#module_binding mb
                  | mb -> super#module_binding mb
                method ctyp =
                  function
                  | Ast.TyPol (_, (Ast.TyNil _), t) |
                      Ast.TyAli (_, (Ast.TyNil _), t) |
                      Ast.TyAli (_, t, (Ast.TyNil _)) |
                      Ast.TyArr (_, t, (Ast.TyNil _)) |
                      Ast.TyArr (_, (Ast.TyNil _), t) |
                      Ast.TyOr (_, (Ast.TyNil _), t) |
                      Ast.TyOr (_, t, (Ast.TyNil _)) |
                      Ast.TyOf (_, t, (Ast.TyNil _)) |
                      Ast.TyAnd (_, (Ast.TyNil _), t) |
                      Ast.TyAnd (_, t, (Ast.TyNil _)) |
                      Ast.TySem (_, t, (Ast.TyNil _)) |
                      Ast.TySem (_, (Ast.TyNil _), t) |
                      Ast.TyCom (_, (Ast.TyNil _), t) |
                      Ast.TyCom (_, t, (Ast.TyNil _)) |
                      Ast.TyAmp (_, t, (Ast.TyNil _)) |
                      Ast.TyAmp (_, (Ast.TyNil _), t) |
                      Ast.TySta (_, (Ast.TyNil _), t) |
                      Ast.TySta (_, t, (Ast.TyNil _)) -> self#ctyp t
                  | t -> super#ctyp t
                method sig_item =
                  function
                  | Ast.SgSem (_, (Ast.SgNil _), sg) |
                      Ast.SgSem (_, sg, (Ast.SgNil _)) -> self#sig_item sg
                  | sg -> super#sig_item sg
                method str_item =
                  function
                  | Ast.StSem (_, (Ast.StNil _), st) |
                      Ast.StSem (_, st, (Ast.StNil _)) -> self#str_item st
                  | st -> super#str_item st
                method module_type =
                  function
                  | Ast.MtWit (_, mt, (Ast.WcNil _)) -> self#module_type mt
                  | mt -> super#module_type mt
                method class_expr =
                  function
                  | Ast.CeAnd (_, (Ast.CeNil _), ce) |
                      Ast.CeAnd (_, ce, (Ast.CeNil _)) -> self#class_expr ce
                  | ce -> super#class_expr ce
                method class_type =
                  function
                  | Ast.CtAnd (_, (Ast.CtNil _), ct) |
                      Ast.CtAnd (_, ct, (Ast.CtNil _)) -> self#class_type ct
                  | ct -> super#class_type ct
                method class_sig_item =
                  function
                  | Ast.CgSem (_, (Ast.CgNil _), csg) |
                      Ast.CgSem (_, csg, (Ast.CgNil _)) ->
                      self#class_sig_item csg
                  | csg -> super#class_sig_item csg
                method class_str_item =
                  function
                  | Ast.CrSem (_, (Ast.CrNil _), cst) |
                      Ast.CrSem (_, cst, (Ast.CrNil _)) ->
                      self#class_str_item cst
                  | cst -> super#class_str_item cst
              end
          end
      end
    module CommentFilter :
      sig
        module Make (Token : Sig.Camlp4Token) :
          sig
            open Token
            type t
            val mk : unit -> t
            val define : Token.Filter.t -> t -> unit
            val filter :
              t -> (Token.t * Loc.t) Stream.t -> (Token.t * Loc.t) Stream.t
            val take_list : t -> (string * Loc.t) list
            val take_stream : t -> (string * Loc.t) Stream.t
          end
      end =
      struct
        module Make (Token : Sig.Camlp4Token) =
          struct
            open Token
            type t =
              (((string * Loc.t) Stream.t) * ((string * Loc.t) Queue.t))
            let mk () =
              let q = Queue.create () in
              let f _ = try Some (Queue.take q) with | Queue.Empty -> None
              in ((Stream.from f), q)
            let filter (_, q) =
              let rec self (__strm : _ Stream.t) =
                match Stream.peek __strm with
                | Some ((Sig.COMMENT x, loc)) ->
                    (Stream.junk __strm;
                     let xs = __strm in (Queue.add (x, loc) q; self xs))
                | Some x ->
                    (Stream.junk __strm;
                     let xs = __strm
                     in Stream.icons x (Stream.slazy (fun _ -> self xs)))
                | _ -> Stream.sempty
              in self
            let take_list (_, q) =
              let rec self accu =
                if Queue.is_empty q
                then accu
                else self ((Queue.take q) :: accu)
              in self []
            let take_stream = fst
            let define token_fiter comments_strm =
              Token.Filter.define_filter token_fiter
                (fun previous strm -> previous (filter comments_strm strm))
          end
      end
    module DynLoader : sig include Sig.DynLoader end =
      struct
        type t = string Queue.t
        exception Error of string * string
        let include_dir x y = Queue.add y x
        let fold_load_path x f acc = Queue.fold (fun x y -> f y x) acc x
        let mk ?(ocaml_stdlib = true) ?(camlp4_stdlib = true) () =
          let q = Queue.create ()
          in
            (if ocaml_stdlib
             then include_dir q Camlp4_config.ocaml_standard_library
             else ();
             if camlp4_stdlib
             then
               (include_dir q Camlp4_config.camlp4_standard_library;
                include_dir q
                  (Filename.concat Camlp4_config.camlp4_standard_library
                     "Camlp4Parsers");
                include_dir q
                  (Filename.concat Camlp4_config.camlp4_standard_library
                     "Camlp4Printers");
                include_dir q
                  (Filename.concat Camlp4_config.camlp4_standard_library
                     "Camlp4Filters"))
             else ();
             include_dir q ".";
             q)
        let find_in_path x name =
          if not (Filename.is_implicit name)
          then if Sys.file_exists name then name else raise Not_found
          else
            (let res =
               fold_load_path x
                 (fun dir ->
                    function
                    | None ->
                        let fullname = Filename.concat dir name
                        in
                          if Sys.file_exists fullname
                          then Some fullname
                          else None
                    | x -> x)
                 None
             in match res with | None -> raise Not_found | Some x -> x)
        let load =
          let _initialized = ref false
          in
            fun _path file ->
              raise
                (Error (file, "native-code program cannot do a dynamic load"))
      end
    module EmptyError : sig include Sig.Error end =
      struct
        type t = unit
        exception E of t
        let print _ = assert false
        let to_string _ = assert false
      end
    module EmptyPrinter :
      sig module Make (Ast : Sig.Ast) : Sig.Printer with module Ast = Ast end =
      struct
        module Make (Ast : Sig.Ast) =
          struct
            module Ast = Ast
            let print_interf ?input_file:(_) ?output_file:(_) _ =
              failwith "No interface printer"
            let print_implem ?input_file:(_) ?output_file:(_) _ =
              failwith "No implementation printer"
          end
      end
    module FreeVars :
      sig
        module Make (Ast : Sig.Camlp4Ast) :
          sig
            module S : Set.S with type elt = string
            val fold_binding_vars :
              (string -> 'accu -> 'accu) -> Ast.binding -> 'accu -> 'accu
            class ['accu] c_fold_pattern_vars :
              (string -> 'accu -> 'accu) ->
                'accu ->
                  object inherit Ast.fold val acc : 'accu method acc : 'accu
                  end
            val fold_pattern_vars :
              (string -> 'accu -> 'accu) -> Ast.patt -> 'accu -> 'accu
            class ['accu] fold_free_vars :
              (string -> 'accu -> 'accu) ->
                ?env_init: S.t ->
                  'accu ->
                    object ('self_type)
                      inherit Ast.fold
                      val free : 'accu
                      val env : S.t
                      method free : 'accu
                      method set_env : S.t -> 'self_type
                      method add_atom : string -> 'self_type
                      method add_patt : Ast.patt -> 'self_type
                      method add_binding : Ast.binding -> 'self_type
                    end
            val free_vars : S.t -> Ast.expr -> S.t
          end
      end =
      struct
        module Make (Ast : Sig.Camlp4Ast) =
          struct
            module S = Set.Make(String)
            let rec fold_binding_vars f bi acc =
              match bi with
              | Ast.BiAnd (_, bi1, bi2) | Ast.BiSem (_, bi1, bi2) ->
                  fold_binding_vars f bi1 (fold_binding_vars f bi2 acc)
              | Ast.BiEq (_, (Ast.PaId (_, (Ast.IdLid (_, i)))), _) ->
                  f i acc
              | _ -> assert false
            class ['accu] c_fold_pattern_vars f init =
              object (o)
                inherit Ast.fold as super
                val acc = init
                method acc : 'accu = acc
                method patt =
                  function
                  | Ast.PaId (_, (Ast.IdLid (_, s))) |
                      Ast.PaLab (_, s, (Ast.PaNil _)) |
                      Ast.PaOlb (_, s, (Ast.PaNil _)) ->
                      {<  acc = f s acc; >}
                  | Ast.PaEq (_, (Ast.PaId (_, (Ast.IdLid (_, _)))), p) ->
                      o#patt p
                  | p -> super#patt p
              end
            let fold_pattern_vars f p init =
              ((new c_fold_pattern_vars f init)#patt p)#acc
            class ['accu] fold_free_vars (f : string -> 'accu -> 'accu)
                    ?(env_init = S.empty) free_init =
              object (o)
                inherit Ast.fold as super
                val free = (free_init : 'accu)
                val env = (env_init : S.t)
                method free = free
                method set_env = fun env -> {<  env = env; >}
                method add_atom = fun s -> {<  env = S.add s env; >}
                method add_patt =
                  fun p -> {<  env = fold_pattern_vars S.add p env; >}
                method add_binding =
                  fun bi -> {<  env = fold_binding_vars S.add bi env; >}
                method expr =
                  function
                  | Ast.ExId (_, (Ast.IdLid (_, s))) |
                      Ast.ExLab (_, s, (Ast.ExNil _)) |
                      Ast.ExOlb (_, s, (Ast.ExNil _)) ->
                      if S.mem s env then o else {<  free = f s free; >}
                  | Ast.ExLet (_, Ast.BFalse, bi, e) ->
                      (((o#add_binding bi)#expr e)#set_env env)#binding bi
                  | Ast.ExLet (_, Ast.BTrue, bi, e) ->
                      (((o#add_binding bi)#expr e)#binding bi)#set_env env
                  | Ast.ExFor (_, s, e1, e2, _, e3) ->
                      ((((o#expr e1)#expr e2)#add_atom s)#expr e3)#set_env
                        env
                  | Ast.ExId (_, _) | Ast.ExNew (_, _) -> o
                  | Ast.ExObj (_, p, cst) ->
                      ((o#add_patt p)#class_str_item cst)#set_env env
                  | e -> super#expr e
                method match_case =
                  function
                  | Ast.McArr (_, p, e1, e2) ->
                      (((o#add_patt p)#expr e1)#expr e2)#set_env env
                  | m -> super#match_case m
                method str_item =
                  function
                  | Ast.StExt (_, s, t, _) -> (o#ctyp t)#add_atom s
                  | Ast.StVal (_, Ast.BFalse, bi) ->
                      (o#binding bi)#add_binding bi
                  | Ast.StVal (_, Ast.BTrue, bi) ->
                      (o#add_binding bi)#binding bi
                  | st -> super#str_item st
                method class_expr =
                  function
                  | Ast.CeFun (_, p, ce) ->
                      ((o#add_patt p)#class_expr ce)#set_env env
                  | Ast.CeLet (_, Ast.BFalse, bi, ce) ->
                      (((o#binding bi)#add_binding bi)#class_expr ce)#set_env
                        env
                  | Ast.CeLet (_, Ast.BTrue, bi, ce) ->
                      (((o#add_binding bi)#binding bi)#class_expr ce)#set_env
                        env
                  | Ast.CeStr (_, p, cst) ->
                      ((o#add_patt p)#class_str_item cst)#set_env env
                  | ce -> super#class_expr ce
                method class_str_item =
                  function
                  | (Ast.CrInh (_, _, "") as cst) -> super#class_str_item cst
                  | Ast.CrInh (_, ce, s) -> (o#class_expr ce)#add_atom s
                  | Ast.CrVal (_, s, _, e) -> (o#expr e)#add_atom s
                  | Ast.CrVvr (_, s, _, t) -> (o#ctyp t)#add_atom s
                  | cst -> super#class_str_item cst
                method module_expr =
                  function
                  | Ast.MeStr (_, st) -> (o#str_item st)#set_env env
                  | me -> super#module_expr me
              end
            let free_vars env_init e =
              let fold = new fold_free_vars S.add ~env_init S.empty
              in (fold#expr e)#free
          end
      end
    module Grammar =
      struct
        module Context =
          struct
            module type S =
              sig
                module Token : Sig.Token
                open Token
                type t
                val call_with_ctx :
                  (Token.t * Loc.t) Stream.t -> (t -> 'a) -> 'a
                val loc_bp : t -> Loc.t
                val loc_ep : t -> Loc.t
                val stream : t -> (Token.t * Loc.t) Stream.t
                val peek_nth : t -> int -> (Token.t * Loc.t) option
                val njunk : t -> int -> unit
                val junk : (Token.t * Loc.t) Stream.t -> unit
                val bp : (Token.t * Loc.t) Stream.t -> Loc.t
              end
            module Make (Token : Sig.Token) : S with module Token = Token =
              struct
                module Token = Token
                open Token
                type t =
                  { mutable strm : (Token.t * Loc.t) Stream.t;
                    mutable loc : Loc.t
                  }
                let loc_bp c =
                  match Stream.peek c.strm with
                  | None -> Loc.ghost
                  | Some ((_, loc)) -> loc
                let loc_ep c = c.loc
                let set_loc c =
                  match Stream.peek c.strm with
                  | Some ((_, loc)) -> c.loc <- loc
                  | None -> ()
                let mk strm =
                  match Stream.peek strm with
                  | Some ((_, loc)) -> {  strm = strm; loc = loc; }
                  | None -> {  strm = strm; loc = Loc.ghost; }
                let stream c = c.strm
                let peek_nth c n =
                  let list = Stream.npeek n c.strm in
                  let rec loop list n =
                    match (list, n) with
                    | ((((_, loc) as x)) :: _, 1) -> (c.loc <- loc; Some x)
                    | (_ :: l, n) -> loop l (n - 1)
                    | ([], _) -> None
                  in loop list n
                let njunk c n =
                  (for i = 1 to n do Stream.junk c.strm done; set_loc c)
                let streams = ref []
                let mk strm =
                  let c = mk strm in
                  let () = streams := (strm, c) :: !streams in c
                let junk strm =
                  (set_loc (List.assq strm !streams); Stream.junk strm)
                let bp strm = loc_bp (List.assq strm !streams)
                let call_with_ctx strm f =
                  let streams_v = !streams in
                  let r =
                    try f (mk strm)
                    with | exc -> (streams := streams_v; raise exc)
                  in (streams := streams_v; r)
              end
          end
        module Structure =
          struct
            open Sig.Grammar
            module type S =
              sig
                module Loc : Sig.Loc
                module Token : Sig.Token with module Loc = Loc
                module Lexer : Sig.Lexer with module Loc = Loc
                  and module Token = Token
                module Context : Context.S with module Token = Token
                module Action : Sig.Grammar.Action
                type gram =
                  { gfilter : Token.Filter.t;
                    gkeywords : (string, int ref) Hashtbl.t;
                    glexer :
                      Loc.t -> char Stream.t -> (Token.t * Loc.t) Stream.t;
                    warning_verbose : bool ref; error_verbose : bool ref
                  }
                type efun =
                  Context.t -> (Token.t * Loc.t) Stream.t -> Action.t
                type token_pattern = ((Token.t -> bool) * string)
                type internal_entry =
                  { egram : gram; ename : string;
                    mutable estart : int -> efun;
                    mutable econtinue : int -> Loc.t -> Action.t -> efun;
                    mutable edesc : desc
                  }
                  and desc =
                  | Dlevels of level list
                  | Dparser of ((Token.t * Loc.t) Stream.t -> Action.t)
                  and level =
                  { assoc : assoc; lname : string option; lsuffix : tree;
                    lprefix : tree
                  }
                  and symbol =
                  | Smeta of string * symbol list * Action.t
                  | Snterm of internal_entry
                  | Snterml of internal_entry * string | Slist0 of symbol
                  | Slist0sep of symbol * symbol | Slist1 of symbol
                  | Slist1sep of symbol * symbol | Sopt of symbol | Sself
                  | Snext | Stoken of token_pattern | Skeyword of string
                  | Stree of tree
                  and tree =
                  | Node of node | LocAct of Action.t * Action.t list
                  | DeadEnd
                  and node =
                  { node : symbol; son : tree; brother : tree
                  }
                type production_rule = ((symbol list) * Action.t)
                type single_extend_statment =
                  ((string option) * (assoc option) * (production_rule list))
                type extend_statment =
                  ((position option) * (single_extend_statment list))
                type delete_statment = symbol list
                type ('a, 'b, 'c) fold =
                  internal_entry ->
                    symbol list -> ('a Stream.t -> 'b) -> 'a Stream.t -> 'c
                type ('a, 'b, 'c) foldsep =
                  internal_entry ->
                    symbol list ->
                      ('a Stream.t -> 'b) ->
                        ('a Stream.t -> unit) -> 'a Stream.t -> 'c
                val get_filter : gram -> Token.Filter.t
                val using : gram -> string -> unit
                val removing : gram -> string -> unit
              end
            module Make (Lexer : Sig.Lexer) =
              struct
                module Loc = Lexer.Loc
                module Token = Lexer.Token
                module Action : Sig.Grammar.Action =
                  struct
                    type t = Obj.t
                    let mk = Obj.repr
                    let get = Obj.obj
                    let getf = Obj.obj
                    let getf2 = Obj.obj
                  end
                module Lexer = Lexer
                type gram =
                  { gfilter : Token.Filter.t;
                    gkeywords : (string, int ref) Hashtbl.t;
                    glexer :
                      Loc.t -> char Stream.t -> (Token.t * Loc.t) Stream.t;
                    warning_verbose : bool ref; error_verbose : bool ref
                  }
                module Context = Context.Make(Token)
                type efun =
                  Context.t -> (Token.t * Loc.t) Stream.t -> Action.t
                type token_pattern = ((Token.t -> bool) * string)
                type internal_entry =
                  { egram : gram; ename : string;
                    mutable estart : int -> efun;
                    mutable econtinue : int -> Loc.t -> Action.t -> efun;
                    mutable edesc : desc
                  }
                  and desc =
                  | Dlevels of level list
                  | Dparser of ((Token.t * Loc.t) Stream.t -> Action.t)
                  and level =
                  { assoc : assoc; lname : string option; lsuffix : tree;
                    lprefix : tree
                  }
                  and symbol =
                  | Smeta of string * symbol list * Action.t
                  | Snterm of internal_entry
                  | Snterml of internal_entry * string | Slist0 of symbol
                  | Slist0sep of symbol * symbol | Slist1 of symbol
                  | Slist1sep of symbol * symbol | Sopt of symbol | Sself
                  | Snext | Stoken of token_pattern | Skeyword of string
                  | Stree of tree
                  and tree =
                  | Node of node | LocAct of Action.t * Action.t list
                  | DeadEnd
                  and node =
                  { node : symbol; son : tree; brother : tree
                  }
                type production_rule = ((symbol list) * Action.t)
                type single_extend_statment =
                  ((string option) * (assoc option) * (production_rule list))
                type extend_statment =
                  ((position option) * (single_extend_statment list))
                type delete_statment = symbol list
                type ('a, 'b, 'c) fold =
                  internal_entry ->
                    symbol list -> ('a Stream.t -> 'b) -> 'a Stream.t -> 'c
                type ('a, 'b, 'c) foldsep =
                  internal_entry ->
                    symbol list ->
                      ('a Stream.t -> 'b) ->
                        ('a Stream.t -> unit) -> 'a Stream.t -> 'c
                let get_filter g = g.gfilter
                type 'a not_filtered = 'a
                let using { gkeywords = table; gfilter = filter } kwd =
                  let r =
                    try Hashtbl.find table kwd
                    with
                    | Not_found ->
                        let r = ref 0 in (Hashtbl.add table kwd r; r)
                  in (Token.Filter.keyword_added filter kwd (!r = 0); incr r)
                let removing { gkeywords = table; gfilter = filter } kwd =
                  let r = Hashtbl.find table kwd in
                  let () = decr r
                  in
                    if !r = 0
                    then
                      (Token.Filter.keyword_removed filter kwd;
                       Hashtbl.remove table kwd)
                    else ()
              end
          end
        module Search =
          struct
            module Make (Structure : Structure.S) =
              struct
                open Structure
                let tree_in_entry prev_symb tree =
                  function
                  | Dlevels levels ->
                      let rec search_levels =
                        (function
                         | [] -> tree
                         | level :: levels ->
                             (match search_level level with
                              | Some tree -> tree
                              | None -> search_levels levels))
                      and search_level level =
                        (match search_tree level.lsuffix with
                         | Some t ->
                             Some
                               (Node
                                  {
                                    
                                    node = Sself;
                                    son = t;
                                    brother = DeadEnd;
                                  })
                         | None -> search_tree level.lprefix)
                      and search_tree t =
                        if (tree <> DeadEnd) && (t == tree)
                        then Some t
                        else
                          (match t with
                           | Node n ->
                               (match search_symbol n.node with
                                | Some symb ->
                                    Some
                                      (Node
                                         {
                                           
                                           node = symb;
                                           son = n.son;
                                           brother = DeadEnd;
                                         })
                                | None ->
                                    (match search_tree n.son with
                                     | Some t ->
                                         Some
                                           (Node
                                              {
                                                
                                                node = n.node;
                                                son = t;
                                                brother = DeadEnd;
                                              })
                                     | None -> search_tree n.brother))
                           | LocAct (_, _) | DeadEnd -> None)
                      and search_symbol symb =
                        (match symb with
                         | Snterm _ | Snterml (_, _) | Slist0 _ |
                             Slist0sep (_, _) | Slist1 _ | Slist1sep (_, _) |
                             Sopt _ | Stoken _ | Stree _ | Skeyword _ when
                             symb == prev_symb -> Some symb
                         | Slist0 symb ->
                             (match search_symbol symb with
                              | Some symb -> Some (Slist0 symb)
                              | None -> None)
                         | Slist0sep (symb, sep) ->
                             (match search_symbol symb with
                              | Some symb -> Some (Slist0sep (symb, sep))
                              | None ->
                                  (match search_symbol sep with
                                   | Some sep -> Some (Slist0sep (symb, sep))
                                   | None -> None))
                         | Slist1 symb ->
                             (match search_symbol symb with
                              | Some symb -> Some (Slist1 symb)
                              | None -> None)
                         | Slist1sep (symb, sep) ->
                             (match search_symbol symb with
                              | Some symb -> Some (Slist1sep (symb, sep))
                              | None ->
                                  (match search_symbol sep with
                                   | Some sep -> Some (Slist1sep (symb, sep))
                                   | None -> None))
                         | Sopt symb ->
                             (match search_symbol symb with
                              | Some symb -> Some (Sopt symb)
                              | None -> None)
                         | Stree t ->
                             (match search_tree t with
                              | Some t -> Some (Stree t)
                              | None -> None)
                         | _ -> None)
                      in search_levels levels
                  | Dparser _ -> tree
              end
          end
        module Tools =
          struct
            module Make (Structure : Structure.S) =
              struct
                open Structure
                let empty_entry ename _ _ _ =
                  raise (Stream.Error ("entry [" ^ (ename ^ "] is empty")))
                let is_level_labelled n lev =
                  match lev.lname with | Some n1 -> n = n1 | None -> false
                let warning_verbose = ref true
                let rec get_token_list entry tokl last_tok tree =
                  match tree with
                  | Node
                      {
                        node = (Stoken _ | Skeyword _ as tok);
                        son = son;
                        brother = DeadEnd
                      } -> get_token_list entry (last_tok :: tokl) tok son
                  | _ ->
                      if tokl = []
                      then None
                      else
                        Some
                          (((List.rev (last_tok :: tokl)), last_tok, tree))
                let is_antiquot s =
                  let len = String.length s in (len > 1) && (s.[0] = '$')
                let eq_Stoken_ids s1 s2 =
                  (not (is_antiquot s1)) &&
                    ((not (is_antiquot s2)) && (s1 = s2))
                let logically_eq_symbols entry =
                  let rec eq_symbols s1 s2 =
                    match (s1, s2) with
                    | (Snterm e1, Snterm e2) -> e1.ename = e2.ename
                    | (Snterm e1, Sself) -> e1.ename = entry.ename
                    | (Sself, Snterm e2) -> entry.ename = e2.ename
                    | (Snterml (e1, l1), Snterml (e2, l2)) ->
                        (e1.ename = e2.ename) && (l1 = l2)
                    | (Slist0 s1, Slist0 s2) -> eq_symbols s1 s2
                    | (Slist0sep (s1, sep1), Slist0sep (s2, sep2)) ->
                        (eq_symbols s1 s2) && (eq_symbols sep1 sep2)
                    | (Slist1 s1, Slist1 s2) -> eq_symbols s1 s2
                    | (Slist1sep (s1, sep1), Slist1sep (s2, sep2)) ->
                        (eq_symbols s1 s2) && (eq_symbols sep1 sep2)
                    | (Sopt s1, Sopt s2) -> eq_symbols s1 s2
                    | (Stree t1, Stree t2) -> eq_trees t1 t2
                    | (Stoken ((_, s1)), Stoken ((_, s2))) ->
                        eq_Stoken_ids s1 s2
                    | _ -> s1 = s2
                  and eq_trees t1 t2 =
                    match (t1, t2) with
                    | (Node n1, Node n2) ->
                        (eq_symbols n1.node n2.node) &&
                          ((eq_trees n1.son n2.son) &&
                             (eq_trees n1.brother n2.brother))
                    | ((LocAct (_, _) | DeadEnd), (LocAct (_, _) | DeadEnd))
                        -> true
                    | _ -> false
                  in eq_symbols
                let rec eq_symbol s1 s2 =
                  match (s1, s2) with
                  | (Snterm e1, Snterm e2) -> e1 == e2
                  | (Snterml (e1, l1), Snterml (e2, l2)) ->
                      (e1 == e2) && (l1 = l2)
                  | (Slist0 s1, Slist0 s2) -> eq_symbol s1 s2
                  | (Slist0sep (s1, sep1), Slist0sep (s2, sep2)) ->
                      (eq_symbol s1 s2) && (eq_symbol sep1 sep2)
                  | (Slist1 s1, Slist1 s2) -> eq_symbol s1 s2
                  | (Slist1sep (s1, sep1), Slist1sep (s2, sep2)) ->
                      (eq_symbol s1 s2) && (eq_symbol sep1 sep2)
                  | (Sopt s1, Sopt s2) -> eq_symbol s1 s2
                  | (Stree _, Stree _) -> false
                  | (Stoken ((_, s1)), Stoken ((_, s2))) ->
                      eq_Stoken_ids s1 s2
                  | _ -> s1 = s2
              end
          end
        module Print :
          sig
            module Make (Structure : Structure.S) :
              sig
                val flatten_tree :
                  Structure.tree -> (Structure.symbol list) list
                val print_symbol :
                  Format.formatter -> Structure.symbol -> unit
                val print_meta :
                  Format.formatter -> string -> Structure.symbol list -> unit
                val print_symbol1 :
                  Format.formatter -> Structure.symbol -> unit
                val print_rule :
                  Format.formatter -> Structure.symbol list -> unit
                val print_level :
                  Format.formatter ->
                    (Format.formatter -> unit -> unit) ->
                      (Structure.symbol list) list -> unit
                val levels : Format.formatter -> Structure.level list -> unit
                val entry :
                  Format.formatter -> Structure.internal_entry -> unit
              end
            module MakeDump (Structure : Structure.S) :
              sig
                val print_symbol :
                  Format.formatter -> Structure.symbol -> unit
                val print_meta :
                  Format.formatter -> string -> Structure.symbol list -> unit
                val print_symbol1 :
                  Format.formatter -> Structure.symbol -> unit
                val print_rule :
                  Format.formatter -> Structure.symbol list -> unit
                val print_level :
                  Format.formatter ->
                    (Format.formatter -> unit -> unit) ->
                      (Structure.symbol list) list -> unit
                val levels : Format.formatter -> Structure.level list -> unit
                val entry :
                  Format.formatter -> Structure.internal_entry -> unit
              end
          end =
          struct
            module Make (Structure : Structure.S) =
              struct
                open Structure
                open Format
                open Sig.Grammar
                let rec flatten_tree =
                  function
                  | DeadEnd -> []
                  | LocAct (_, _) -> [ [] ]
                  | Node { node = n; brother = b; son = s } ->
                      (List.map (fun l -> n :: l) (flatten_tree s)) @
                        (flatten_tree b)
                let rec print_symbol ppf =
                  function
                  | Smeta (n, sl, _) -> print_meta ppf n sl
                  | Slist0 s -> fprintf ppf "LIST0 %a" print_symbol1 s
                  | Slist0sep (s, t) ->
                      fprintf ppf "LIST0 %a SEP %a" print_symbol1 s
                        print_symbol1 t
                  | Slist1 s -> fprintf ppf "LIST1 %a" print_symbol1 s
                  | Slist1sep (s, t) ->
                      fprintf ppf "LIST1 %a SEP %a" print_symbol1 s
                        print_symbol1 t
                  | Sopt s -> fprintf ppf "OPT %a" print_symbol1 s
                  | Snterml (e, l) -> fprintf ppf "%s@ LEVEL@ %S" e.ename l
                  | (Snterm _ | Snext | Sself | Stree _ | Stoken _ |
                       Skeyword _
                     as s) -> print_symbol1 ppf s
                and print_meta ppf n sl =
                  let rec loop i =
                    function
                    | [] -> ()
                    | s :: sl ->
                        let j =
                          (try String.index_from n i ' '
                           with | Not_found -> String.length n)
                        in
                          (fprintf ppf "%s %a" (String.sub n i (j - i))
                             print_symbol1 s;
                           if sl = []
                           then ()
                           else
                             (fprintf ppf " ";
                              loop (min (j + 1) (String.length n)) sl))
                  in loop 0 sl
                and print_symbol1 ppf =
                  function
                  | Snterm e -> pp_print_string ppf e.ename
                  | Sself -> pp_print_string ppf "SELF"
                  | Snext -> pp_print_string ppf "NEXT"
                  | Stoken ((_, descr)) -> pp_print_string ppf descr
                  | Skeyword s -> fprintf ppf "%S" s
                  | Stree t ->
                      print_level ppf pp_print_space (flatten_tree t)
                  | (Smeta (_, _, _) | Snterml (_, _) | Slist0 _ |
                       Slist0sep (_, _) | Slist1 _ | Slist1sep (_, _) |
                       Sopt _
                     as s) -> fprintf ppf "(%a)" print_symbol s
                and print_rule ppf symbols =
                  (fprintf ppf "@[<hov 0>";
                   let _ =
                     List.fold_left
                       (fun sep symbol ->
                          (fprintf ppf "%t%a" sep print_symbol symbol;
                           fun ppf -> fprintf ppf ";@ "))
                       (fun _ -> ()) symbols
                   in fprintf ppf "@]")
                and print_level ppf pp_print_space rules =
                  (fprintf ppf "@[<hov 0>[ ";
                   let _ =
                     List.fold_left
                       (fun sep rule ->
                          (fprintf ppf "%t%a" sep print_rule rule;
                           fun ppf -> fprintf ppf "%a| " pp_print_space ()))
                       (fun _ -> ()) rules
                   in fprintf ppf " ]@]")
                let levels ppf elev =
                  let _ =
                    List.fold_left
                      (fun sep lev ->
                         let rules =
                           (List.map (fun t -> Sself :: t)
                              (flatten_tree lev.lsuffix))
                             @ (flatten_tree lev.lprefix)
                         in
                           (fprintf ppf "%t@[<hov 2>" sep;
                            (match lev.lname with
                             | Some n -> fprintf ppf "%S@;<1 2>" n
                             | None -> ());
                            (match lev.assoc with
                             | LeftA -> fprintf ppf "LEFTA"
                             | RightA -> fprintf ppf "RIGHTA"
                             | NonA -> fprintf ppf "NONA");
                            fprintf ppf "@]@;<1 2>";
                            print_level ppf pp_force_newline rules;
                            fun ppf -> fprintf ppf "@,| "))
                      (fun _ -> ()) elev
                  in ()
                let entry ppf e =
                  (fprintf ppf "@[<v 0>%s: [ " e.ename;
                   (match e.edesc with
                    | Dlevels elev -> levels ppf elev
                    | Dparser _ -> fprintf ppf "<parser>");
                   fprintf ppf " ]@]")
              end
            module MakeDump (Structure : Structure.S) =
              struct
                open Structure
                open Format
                open Sig.Grammar
                type brothers = | Bro of symbol * brothers list
                let rec print_tree ppf tree =
                  let rec get_brothers acc =
                    function
                    | DeadEnd -> List.rev acc
                    | LocAct (_, _) -> List.rev acc
                    | Node { node = n; brother = b; son = s } ->
                        get_brothers ((Bro (n, get_brothers [] s)) :: acc) b
                  and print_brothers ppf brothers =
                    if brothers = []
                    then fprintf ppf "@ []"
                    else
                      List.iter
                        (function
                         | Bro (n, xs) ->
                             (fprintf ppf "@ @[<hv2>- %a" print_symbol n;
                              (match xs with
                               | [] -> ()
                               | [ _ ] ->
                                   (try
                                      print_children ppf (get_children [] xs)
                                    with
                                    | Exit ->
                                        fprintf ppf ":%a" print_brothers xs)
                               | _ -> fprintf ppf ":%a" print_brothers xs);
                              fprintf ppf "@]"))
                        brothers
                  and print_children ppf =
                    List.iter (fprintf ppf ";@ %a" print_symbol)
                  and get_children acc =
                    function
                    | [] -> List.rev acc
                    | [ Bro (n, x) ] -> get_children (n :: acc) x
                    | _ -> raise Exit
                  in print_brothers ppf (get_brothers [] tree)
                and print_symbol ppf =
                  function
                  | Smeta (n, sl, _) -> print_meta ppf n sl
                  | Slist0 s -> fprintf ppf "LIST0 %a" print_symbol1 s
                  | Slist0sep (s, t) ->
                      fprintf ppf "LIST0 %a SEP %a" print_symbol1 s
                        print_symbol1 t
                  | Slist1 s -> fprintf ppf "LIST1 %a" print_symbol1 s
                  | Slist1sep (s, t) ->
                      fprintf ppf "LIST1 %a SEP %a" print_symbol1 s
                        print_symbol1 t
                  | Sopt s -> fprintf ppf "OPT %a" print_symbol1 s
                  | Snterml (e, l) -> fprintf ppf "%s@ LEVEL@ %S" e.ename l
                  | (Snterm _ | Snext | Sself | Stree _ | Stoken _ |
                       Skeyword _
                     as s) -> print_symbol1 ppf s
                and print_meta ppf n sl =
                  let rec loop i =
                    function
                    | [] -> ()
                    | s :: sl ->
                        let j =
                          (try String.index_from n i ' '
                           with | Not_found -> String.length n)
                        in
                          (fprintf ppf "%s %a" (String.sub n i (j - i))
                             print_symbol1 s;
                           if sl = []
                           then ()
                           else
                             (fprintf ppf " ";
                              loop (min (j + 1) (String.length n)) sl))
                  in loop 0 sl
                and print_symbol1 ppf =
                  function
                  | Snterm e -> pp_print_string ppf e.ename
                  | Sself -> pp_print_string ppf "SELF"
                  | Snext -> pp_print_string ppf "NEXT"
                  | Stoken ((_, descr)) -> pp_print_string ppf descr
                  | Skeyword s -> fprintf ppf "%S" s
                  | Stree t -> print_tree ppf t
                  | (Smeta (_, _, _) | Snterml (_, _) | Slist0 _ |
                       Slist0sep (_, _) | Slist1 _ | Slist1sep (_, _) |
                       Sopt _
                     as s) -> fprintf ppf "(%a)" print_symbol s
                and print_rule ppf symbols =
                  (fprintf ppf "@[<hov 0>";
                   let _ =
                     List.fold_left
                       (fun sep symbol ->
                          (fprintf ppf "%t%a" sep print_symbol symbol;
                           fun ppf -> fprintf ppf ";@ "))
                       (fun _ -> ()) symbols
                   in fprintf ppf "@]")
                and print_level ppf pp_print_space rules =
                  (fprintf ppf "@[<hov 0>[ ";
                   let _ =
                     List.fold_left
                       (fun sep rule ->
                          (fprintf ppf "%t%a" sep print_rule rule;
                           fun ppf -> fprintf ppf "%a| " pp_print_space ()))
                       (fun _ -> ()) rules
                   in fprintf ppf " ]@]")
                let levels ppf elev =
                  let _ =
                    List.fold_left
                      (fun sep lev ->
                         (fprintf ppf "%t@[<v2>" sep;
                          (match lev.lname with
                           | Some n -> fprintf ppf "%S@;<1 2>" n
                           | None -> ());
                          (match lev.assoc with
                           | LeftA -> fprintf ppf "LEFTA"
                           | RightA -> fprintf ppf "RIGHTA"
                           | NonA -> fprintf ppf "NONA");
                          fprintf ppf "@]@;<1 2>";
                          fprintf ppf "@[<v2>suffix:@ ";
                          print_tree ppf lev.lsuffix;
                          fprintf ppf "@]@ @[<v2>prefix:@ ";
                          print_tree ppf lev.lprefix;
                          fprintf ppf "@]";
                          fun ppf -> fprintf ppf "@,| "))
                      (fun _ -> ()) elev
                  in ()
                let entry ppf e =
                  (fprintf ppf "@[<v 0>%s: [ " e.ename;
                   (match e.edesc with
                    | Dlevels elev -> levels ppf elev
                    | Dparser _ -> fprintf ppf "<parser>");
                   fprintf ppf " ]@]")
              end
          end
        module Failed =
          struct
            module Make (Structure : Structure.S) =
              struct
                module Tools = Tools.Make(Structure)
                module Search = Search.Make(Structure)
                module Print = Print.Make(Structure)
                open Structure
                open Format
                let rec name_of_symbol entry =
                  function
                  | Snterm e -> "[" ^ (e.ename ^ "]")
                  | Snterml (e, l) ->
                      "[" ^ (e.ename ^ (" level " ^ (l ^ "]")))
                  | Sself | Snext -> "[" ^ (entry.ename ^ "]")
                  | Stoken ((_, descr)) -> descr
                  | Skeyword kwd -> "\"" ^ (kwd ^ "\"")
                  | _ -> "???"
                let rec name_of_symbol_failed entry =
                  function
                  | Slist0 s -> name_of_symbol_failed entry s
                  | Slist0sep (s, _) -> name_of_symbol_failed entry s
                  | Slist1 s -> name_of_symbol_failed entry s
                  | Slist1sep (s, _) -> name_of_symbol_failed entry s
                  | Sopt s -> name_of_symbol_failed entry s
                  | Stree t -> name_of_tree_failed entry t
                  | s -> name_of_symbol entry s
                and name_of_tree_failed entry =
                  function
                  | Node { node = s; brother = bro; son = son } ->
                      let tokl =
                        (match s with
                         | Stoken _ | Skeyword _ ->
                             Tools.get_token_list entry [] s son
                         | _ -> None)
                      in
                        (match tokl with
                         | None ->
                             let txt = name_of_symbol_failed entry s in
                             let txt =
                               (match (s, son) with
                                | (Sopt _, Node _) ->
                                    txt ^
                                      (" or " ^
                                         (name_of_tree_failed entry son))
                                | _ -> txt) in
                             let txt =
                               (match bro with
                                | DeadEnd | LocAct (_, _) -> txt
                                | Node _ ->
                                    txt ^
                                      (" or " ^
                                         (name_of_tree_failed entry bro)))
                             in txt
                         | Some ((tokl, _, _)) ->
                             List.fold_left
                               (fun s tok ->
                                  (if s = "" then "" else s ^ " then ") ^
                                    (match tok with
                                     | Stoken ((_, descr)) -> descr
                                     | Skeyword kwd -> kwd
                                     | _ -> assert false))
                               "" tokl)
                  | DeadEnd | LocAct (_, _) -> "???"
                let magic _s x = Obj.magic x
                let tree_failed entry prev_symb_result prev_symb tree =
                  let txt = name_of_tree_failed entry tree in
                  let txt =
                    match prev_symb with
                    | Slist0 s ->
                        let txt1 = name_of_symbol_failed entry s
                        in txt1 ^ (" or " ^ (txt ^ " expected"))
                    | Slist1 s ->
                        let txt1 = name_of_symbol_failed entry s
                        in txt1 ^ (" or " ^ (txt ^ " expected"))
                    | Slist0sep (s, sep) ->
                        (match magic "tree_failed: 'a -> list 'b"
                                 prev_symb_result
                         with
                         | [] ->
                             let txt1 = name_of_symbol_failed entry s
                             in txt1 ^ (" or " ^ (txt ^ " expected"))
                         | _ ->
                             let txt1 = name_of_symbol_failed entry sep
                             in txt1 ^ (" or " ^ (txt ^ " expected")))
                    | Slist1sep (s, sep) ->
                        (match magic "tree_failed: 'a -> list 'b"
                                 prev_symb_result
                         with
                         | [] ->
                             let txt1 = name_of_symbol_failed entry s
                             in txt1 ^ (" or " ^ (txt ^ " expected"))
                         | _ ->
                             let txt1 = name_of_symbol_failed entry sep
                             in txt1 ^ (" or " ^ (txt ^ " expected")))
                    | Sopt _ | Stree _ -> txt ^ " expected"
                    | _ ->
                        txt ^
                          (" expected after " ^
                             (name_of_symbol entry prev_symb))
                  in
                    (if !(entry.egram.error_verbose)
                     then
                       (let tree =
                          Search.tree_in_entry prev_symb tree entry.edesc in
                        let ppf = err_formatter
                        in
                          (fprintf ppf "@[<v 0>@,";
                           fprintf ppf "----------------------------------@,";
                           fprintf ppf
                             "Parse error in entry [%s], rule:@;<0 2>"
                             entry.ename;
                           fprintf ppf "@[";
                           Print.print_level ppf pp_force_newline
                             (Print.flatten_tree tree);
                           fprintf ppf "@]@,";
                           fprintf ppf "----------------------------------@,";
                           fprintf ppf "@]@."))
                     else ();
                     txt ^ (" (in [" ^ (entry.ename ^ "])")))
                let symb_failed entry prev_symb_result prev_symb symb =
                  let tree =
                    Node {  node = symb; brother = DeadEnd; son = DeadEnd; }
                  in tree_failed entry prev_symb_result prev_symb tree
                let symb_failed_txt e s1 s2 = symb_failed e 0 s1 s2
              end
          end
        module Parser =
          struct
            module Make (Structure : Structure.S) =
              struct
                module Tools = Tools.Make(Structure)
                module Failed = Failed.Make(Structure)
                module Print = Print.Make(Structure)
                open Structure
                open Sig.Grammar
                module Stream =
                  struct
                    include Stream
                    let junk strm = Context.junk strm
                    let count strm = Context.bp strm
                  end
                let add_loc c bp parse_fun strm =
                  let x = parse_fun c strm in
                  let ep = Context.loc_ep c in
                  let loc = Loc.merge bp ep in (x, loc)
                let level_number entry lab =
                  let rec lookup levn =
                    function
                    | [] -> failwith ("unknown level " ^ lab)
                    | lev :: levs ->
                        if Tools.is_level_labelled lab lev
                        then levn
                        else lookup (succ levn) levs
                  in
                    match entry.edesc with
                    | Dlevels elev -> lookup 0 elev
                    | Dparser _ -> raise Not_found
                let strict_parsing = ref false
                let strict_parsing_warning = ref false
                let rec top_symb entry =
                  function
                  | Sself | Snext -> Snterm entry
                  | Snterml (e, _) -> Snterm e
                  | Slist1sep (s, sep) -> Slist1sep (top_symb entry s, sep)
                  | _ -> raise Stream.Failure
                let top_tree entry =
                  function
                  | Node { node = s; brother = bro; son = son } ->
                      Node
                        {  node = top_symb entry s; brother = bro; son = son;
                        }
                  | LocAct (_, _) | DeadEnd -> raise Stream.Failure
                let entry_of_symb entry =
                  function
                  | Sself | Snext -> entry
                  | Snterm e -> e
                  | Snterml (e, _) -> e
                  | _ -> raise Stream.Failure
                let continue entry loc a s c son p1 (__strm : _ Stream.t) =
                  let a =
                    (entry_of_symb entry s).econtinue 0 loc a c __strm in
                  let act =
                    try p1 __strm
                    with
                    | Stream.Failure ->
                        raise
                          (Stream.Error (Failed.tree_failed entry a s son))
                  in Action.mk (fun _ -> Action.getf act a)
                let skip_if_empty c bp p strm =
                  if (Context.loc_ep c) == bp
                  then Action.mk (fun _ -> p strm)
                  else raise Stream.Failure
                let do_recover parser_of_tree entry nlevn alevn loc a s c son
                               (__strm : _ Stream.t) =
                  try
                    parser_of_tree entry nlevn alevn (top_tree entry son) c
                      __strm
                  with
                  | Stream.Failure ->
                      (try
                         skip_if_empty c loc
                           (fun (__strm : _ Stream.t) -> raise Stream.Failure)
                           __strm
                       with
                       | Stream.Failure ->
                           continue entry loc a s c son
                             (parser_of_tree entry nlevn alevn son c) __strm)
                let recover parser_of_tree entry nlevn alevn loc a s c son
                            strm =
                  if !strict_parsing
                  then
                    raise (Stream.Error (Failed.tree_failed entry a s son))
                  else
                    (let _ =
                       if !strict_parsing_warning
                       then
                         (let msg = Failed.tree_failed entry a s son
                          in
                            (Format.eprintf
                               "Warning: trying to recover from syntax error";
                             if entry.ename <> ""
                             then Format.eprintf " in [%s]" entry.ename
                             else ();
                             Format.eprintf "\n%s%a@." msg Loc.print loc))
                       else ()
                     in
                       do_recover parser_of_tree entry nlevn alevn loc a s c
                         son strm)
                let rec parser_of_tree entry nlevn alevn =
                  function
                  | DeadEnd ->
                      (fun _ (__strm : _ Stream.t) -> raise Stream.Failure)
                  | LocAct (act, _) -> (fun _ (__strm : _ Stream.t) -> act)
                  | Node
                      {
                        node = Sself;
                        son = LocAct (act, _);
                        brother = DeadEnd
                      } ->
                      (fun c (__strm : _ Stream.t) ->
                         let a = entry.estart alevn c __strm
                         in Action.getf act a)
                  | Node { node = Sself; son = LocAct (act, _); brother = bro
                      } ->
                      let p2 = parser_of_tree entry nlevn alevn bro
                      in
                        (fun c (__strm : _ Stream.t) ->
                           match try Some (entry.estart alevn c __strm)
                                 with | Stream.Failure -> None
                           with
                           | Some a -> Action.getf act a
                           | _ -> p2 c __strm)
                  | Node { node = s; son = son; brother = DeadEnd } ->
                      let tokl =
                        (match s with
                         | Stoken _ | Skeyword _ ->
                             Tools.get_token_list entry [] s son
                         | _ -> None)
                      in
                        (match tokl with
                         | None ->
                             let ps = parser_of_symbol entry nlevn s in
                             let p1 = parser_of_tree entry nlevn alevn son in
                             let p1 = parser_cont p1 entry nlevn alevn s son
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  let bp = Stream.count __strm in
                                  let a = ps c __strm in
                                  let act =
                                    try p1 c bp a __strm
                                    with
                                    | Stream.Failure ->
                                        raise (Stream.Error "")
                                  in Action.getf act a)
                         | Some ((tokl, last_tok, son)) ->
                             let p1 = parser_of_tree entry nlevn alevn son in
                             let p1 =
                               parser_cont p1 entry nlevn alevn last_tok son
                             in parser_of_token_list p1 tokl)
                  | Node { node = s; son = son; brother = bro } ->
                      let tokl =
                        (match s with
                         | Stoken _ | Skeyword _ ->
                             Tools.get_token_list entry [] s son
                         | _ -> None)
                      in
                        (match tokl with
                         | None ->
                             let ps = parser_of_symbol entry nlevn s in
                             let p1 = parser_of_tree entry nlevn alevn son in
                             let p1 =
                               parser_cont p1 entry nlevn alevn s son in
                             let p2 = parser_of_tree entry nlevn alevn bro
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  let bp = Stream.count __strm
                                  in
                                    match try Some (ps c __strm)
                                          with | Stream.Failure -> None
                                    with
                                    | Some a ->
                                        let act =
                                          (try p1 c bp a __strm
                                           with
                                           | Stream.Failure ->
                                               raise (Stream.Error ""))
                                        in Action.getf act a
                                    | _ -> p2 c __strm)
                         | Some ((tokl, last_tok, son)) ->
                             let p1 = parser_of_tree entry nlevn alevn son in
                             let p1 =
                               parser_cont p1 entry nlevn alevn last_tok son in
                             let p1 = parser_of_token_list p1 tokl in
                             let p2 = parser_of_tree entry nlevn alevn bro
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  try p1 c __strm
                                  with | Stream.Failure -> p2 c __strm))
                and
                  parser_cont p1 entry nlevn alevn s son c loc a
                              (__strm : _ Stream.t) =
                  try p1 c __strm
                  with
                  | Stream.Failure ->
                      (try
                         recover parser_of_tree entry nlevn alevn loc a s c
                           son __strm
                       with
                       | Stream.Failure ->
                           raise
                             (Stream.Error (Failed.tree_failed entry a s son)))
                and parser_of_token_list p1 tokl =
                  let rec loop n =
                    function
                    | Stoken ((tematch, _)) :: tokl ->
                        (match tokl with
                         | [] ->
                             let ps c _ =
                               (match Context.peek_nth c n with
                                | Some ((tok, _)) when tematch tok ->
                                    (Context.njunk c n; Action.mk tok)
                                | _ -> raise Stream.Failure)
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  let bp = Stream.count __strm in
                                  let a = ps c __strm in
                                  let act =
                                    try p1 c bp a __strm
                                    with
                                    | Stream.Failure ->
                                        raise (Stream.Error "")
                                  in Action.getf act a)
                         | _ ->
                             let ps c _ =
                               (match Context.peek_nth c n with
                                | Some ((tok, _)) when tematch tok -> tok
                                | _ -> raise Stream.Failure) in
                             let p1 = loop (n + 1) tokl
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  let tok = ps c __strm in
                                  let s = __strm in
                                  let act = p1 c s in Action.getf act tok))
                    | Skeyword kwd :: tokl ->
                        (match tokl with
                         | [] ->
                             let ps c _ =
                               (match Context.peek_nth c n with
                                | Some ((tok, _)) when
                                    Token.match_keyword kwd tok ->
                                    (Context.njunk c n; Action.mk tok)
                                | _ -> raise Stream.Failure)
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  let bp = Stream.count __strm in
                                  let a = ps c __strm in
                                  let act =
                                    try p1 c bp a __strm
                                    with
                                    | Stream.Failure ->
                                        raise (Stream.Error "")
                                  in Action.getf act a)
                         | _ ->
                             let ps c _ =
                               (match Context.peek_nth c n with
                                | Some ((tok, _)) when
                                    Token.match_keyword kwd tok -> tok
                                | _ -> raise Stream.Failure) in
                             let p1 = loop (n + 1) tokl
                             in
                               (fun c (__strm : _ Stream.t) ->
                                  let tok = ps c __strm in
                                  let s = __strm in
                                  let act = p1 c s in Action.getf act tok))
                    | _ -> invalid_arg "parser_of_token_list"
                  in loop 1 tokl
                and parser_of_symbol entry nlevn =
                  function
                  | Smeta (_, symbl, act) ->
                      let act = Obj.magic act entry symbl in
                      let pl = List.map (parser_of_symbol entry nlevn) symbl
                      in
                        (fun c ->
                           Obj.magic
                             (List.fold_left
                                (fun act p -> Obj.magic act (p c)) act pl))
                  | Slist0 s ->
                      let ps = parser_of_symbol entry nlevn s in
                      let rec loop c al (__strm : _ Stream.t) =
                        (match try Some (ps c __strm)
                               with | Stream.Failure -> None
                         with
                         | Some a -> loop c (a :: al) __strm
                         | _ -> al)
                      in
                        (fun c (__strm : _ Stream.t) ->
                           let a = loop c [] __strm in Action.mk (List.rev a))
                  | Slist0sep (symb, sep) ->
                      let ps = parser_of_symbol entry nlevn symb in
                      let pt = parser_of_symbol entry nlevn sep in
                      let rec kont c al (__strm : _ Stream.t) =
                        (match try Some (pt c __strm)
                               with | Stream.Failure -> None
                         with
                         | Some v ->
                             let a =
                               (try ps c __strm
                                with
                                | Stream.Failure ->
                                    raise
                                      (Stream.Error
                                         (Failed.symb_failed entry v sep symb)))
                             in kont c (a :: al) __strm
                         | _ -> al)
                      in
                        (fun c (__strm : _ Stream.t) ->
                           match try Some (ps c __strm)
                                 with | Stream.Failure -> None
                           with
                           | Some a ->
                               let s = __strm
                               in Action.mk (List.rev (kont c [ a ] s))
                           | _ -> Action.mk [])
                  | Slist1 s ->
                      let ps = parser_of_symbol entry nlevn s in
                      let rec loop c al (__strm : _ Stream.t) =
                        (match try Some (ps c __strm)
                               with | Stream.Failure -> None
                         with
                         | Some a -> loop c (a :: al) __strm
                         | _ -> al)
                      in
                        (fun c (__strm : _ Stream.t) ->
                           let a = ps c __strm in
                           let s = __strm
                           in Action.mk (List.rev (loop c [ a ] s)))
                  | Slist1sep (symb, sep) ->
                      let ps = parser_of_symbol entry nlevn symb in
                      let pt = parser_of_symbol entry nlevn sep in
                      let rec kont c al (__strm : _ Stream.t) =
                        (match try Some (pt c __strm)
                               with | Stream.Failure -> None
                         with
                         | Some v ->
                             let a =
                               (try ps c __strm
                                with
                                | Stream.Failure ->
                                    (try parse_top_symb' entry symb c __strm
                                     with
                                     | Stream.Failure ->
                                         raise
                                           (Stream.Error
                                              (Failed.symb_failed entry v sep
                                                 symb))))
                             in kont c (a :: al) __strm
                         | _ -> al)
                      in
                        (fun c (__strm : _ Stream.t) ->
                           let a = ps c __strm in
                           let s = __strm
                           in Action.mk (List.rev (kont c [ a ] s)))
                  | Sopt s ->
                      let ps = parser_of_symbol entry nlevn s
                      in
                        (fun c (__strm : _ Stream.t) ->
                           match try Some (ps c __strm)
                                 with | Stream.Failure -> None
                           with
                           | Some a -> Action.mk (Some a)
                           | _ -> Action.mk None)
                  | Stree t ->
                      let pt = parser_of_tree entry 1 0 t
                      in
                        (fun c (__strm : _ Stream.t) ->
                           let bp = Stream.count __strm in
                           let (act, loc) = add_loc c bp pt __strm
                           in Action.getf act loc)
                  | Snterm e ->
                      (fun c (__strm : _ Stream.t) -> e.estart 0 c __strm)
                  | Snterml (e, l) ->
                      (fun c (__strm : _ Stream.t) ->
                         e.estart (level_number e l) c __strm)
                  | Sself ->
                      (fun c (__strm : _ Stream.t) -> entry.estart 0 c __strm)
                  | Snext ->
                      (fun c (__strm : _ Stream.t) ->
                         entry.estart nlevn c __strm)
                  | Skeyword kwd ->
                      (fun _ (__strm : _ Stream.t) ->
                         match Stream.peek __strm with
                         | Some ((tok, _)) when Token.match_keyword kwd tok
                             -> (Stream.junk __strm; Action.mk tok)
                         | _ -> raise Stream.Failure)
                  | Stoken ((f, _)) ->
                      (fun _ (__strm : _ Stream.t) ->
                         match Stream.peek __strm with
                         | Some ((tok, _)) when f tok ->
                             (Stream.junk __strm; Action.mk tok)
                         | _ -> raise Stream.Failure)
                and parse_top_symb' entry symb c =
                  parser_of_symbol entry 0 (top_symb entry symb) c
                and parse_top_symb entry symb strm =
                  Context.call_with_ctx strm
                    (fun c -> parse_top_symb' entry symb c (Context.stream c))
                let rec start_parser_of_levels entry clevn =
                  function
                  | [] ->
                      (fun _ _ (__strm : _ Stream.t) -> raise Stream.Failure)
                  | lev :: levs ->
                      let p1 = start_parser_of_levels entry (succ clevn) levs
                      in
                        (match lev.lprefix with
                         | DeadEnd -> p1
                         | tree ->
                             let alevn =
                               (match lev.assoc with
                                | LeftA | NonA -> succ clevn
                                | RightA -> clevn) in
                             let p2 =
                               parser_of_tree entry (succ clevn) alevn tree
                             in
                               (match levs with
                                | [] ->
                                    (fun levn c (__strm : _ Stream.t) ->
                                       let bp = Stream.count __strm in
                                       let (act, loc) =
                                         add_loc c bp p2 __strm in
                                       let strm = __strm in
                                       let a = Action.getf act loc
                                       in entry.econtinue levn loc a c strm)
                                | _ ->
                                    (fun levn c strm ->
                                       if levn > clevn
                                       then p1 levn c strm
                                       else
                                         (let (__strm : _ Stream.t) = strm in
                                          let bp = Stream.count __strm
                                          in
                                            match try
                                                    Some
                                                      (add_loc c bp p2 __strm)
                                                  with
                                                  | Stream.Failure -> None
                                            with
                                            | Some ((act, loc)) ->
                                                let a = Action.getf act loc
                                                in
                                                  entry.econtinue levn loc a
                                                    c strm
                                            | _ -> p1 levn c __strm))))
                let start_parser_of_entry entry =
                  match entry.edesc with
                  | Dlevels [] -> Tools.empty_entry entry.ename
                  | Dlevels elev -> start_parser_of_levels entry 0 elev
                  | Dparser p -> (fun _ _ strm -> p strm)
                let rec continue_parser_of_levels entry clevn =
                  function
                  | [] ->
                      (fun _ _ _ _ (__strm : _ Stream.t) ->
                         raise Stream.Failure)
                  | lev :: levs ->
                      let p1 =
                        continue_parser_of_levels entry (succ clevn) levs
                      in
                        (match lev.lsuffix with
                         | DeadEnd -> p1
                         | tree ->
                             let alevn =
                               (match lev.assoc with
                                | LeftA | NonA -> succ clevn
                                | RightA -> clevn) in
                             let p2 =
                               parser_of_tree entry (succ clevn) alevn tree
                             in
                               (fun c levn bp a strm ->
                                  if levn > clevn
                                  then p1 c levn bp a strm
                                  else
                                    (let (__strm : _ Stream.t) = strm in
                                     let bp = Stream.count __strm
                                     in
                                       try p1 c levn bp a __strm
                                       with
                                       | Stream.Failure ->
                                           let (act, loc) =
                                             add_loc c bp p2 __strm in
                                           let a = Action.getf2 act a loc
                                           in
                                             entry.econtinue levn loc a c
                                               strm)))
                let continue_parser_of_entry entry =
                  match entry.edesc with
                  | Dlevels elev ->
                      let p = continue_parser_of_levels entry 0 elev
                      in
                        (fun levn bp a c (__strm : _ Stream.t) ->
                           try p c levn bp a __strm
                           with | Stream.Failure -> a)
                  | Dparser _ ->
                      (fun _ _ _ _ (__strm : _ Stream.t) ->
                         raise Stream.Failure)
              end
          end
        module Insert =
          struct
            module Make (Structure : Structure.S) =
              struct
                module Tools = Tools.Make(Structure)
                module Parser = Parser.Make(Structure)
                open Structure
                open Format
                open Sig.Grammar
                let is_before s1 s2 =
                  match (s1, s2) with
                  | ((Skeyword _ | Stoken _), (Skeyword _ | Stoken _)) ->
                      false
                  | ((Skeyword _ | Stoken _), _) -> true
                  | _ -> false
                let rec derive_eps =
                  function
                  | Slist0 _ -> true
                  | Slist0sep (_, _) -> true
                  | Sopt _ -> true
                  | Stree t -> tree_derive_eps t
                  | Smeta (_, _, _) | Slist1 _ | Slist1sep (_, _) | Snterm _
                      | Snterml (_, _) | Snext | Sself | Stoken _ |
                      Skeyword _ -> false
                and tree_derive_eps =
                  function
                  | LocAct (_, _) -> true
                  | Node { node = s; brother = bro; son = son } ->
                      ((derive_eps s) && (tree_derive_eps son)) ||
                        (tree_derive_eps bro)
                  | DeadEnd -> false
                let empty_lev lname assoc =
                  let assoc = match assoc with | Some a -> a | None -> LeftA
                  in
                    {
                      
                      assoc = assoc;
                      lname = lname;
                      lsuffix = DeadEnd;
                      lprefix = DeadEnd;
                    }
                let change_lev entry lev n lname assoc =
                  let a =
                    match assoc with
                    | None -> lev.assoc
                    | Some a ->
                        (if
                           (a <> lev.assoc) && !(entry.egram.warning_verbose)
                         then
                           (eprintf
                              "<W> Changing associativity of level \"%s\"\n"
                              n;
                            flush stderr)
                         else ();
                         a)
                  in
                    ((match lname with
                      | Some n ->
                          if
                            (lname <> lev.lname) &&
                              !(entry.egram.warning_verbose)
                          then
                            (eprintf "<W> Level label \"%s\" ignored\n" n;
                             flush stderr)
                          else ()
                      | None -> ());
                     {
                       
                       assoc = a;
                       lname = lev.lname;
                       lsuffix = lev.lsuffix;
                       lprefix = lev.lprefix;
                     })
                let change_to_self entry =
                  function | Snterm e when e == entry -> Sself | x -> x
                let get_level entry position levs =
                  match position with
                  | Some First -> ([], empty_lev, levs)
                  | Some Last -> (levs, empty_lev, [])
                  | Some (Level n) ->
                      let rec get =
                        (function
                         | [] ->
                             (eprintf
                                "No level labelled \"%s\" in entry \"%s\"\n"
                                n entry.ename;
                              flush stderr;
                              failwith "Grammar.extend")
                         | lev :: levs ->
                             if Tools.is_level_labelled n lev
                             then ([], (change_lev entry lev n), levs)
                             else
                               (let (levs1, rlev, levs2) = get levs
                                in ((lev :: levs1), rlev, levs2)))
                      in get levs
                  | Some (Before n) ->
                      let rec get =
                        (function
                         | [] ->
                             (eprintf
                                "No level labelled \"%s\" in entry \"%s\"\n"
                                n entry.ename;
                              flush stderr;
                              failwith "Grammar.extend")
                         | lev :: levs ->
                             if Tools.is_level_labelled n lev
                             then ([], empty_lev, (lev :: levs))
                             else
                               (let (levs1, rlev, levs2) = get levs
                                in ((lev :: levs1), rlev, levs2)))
                      in get levs
                  | Some (After n) ->
                      let rec get =
                        (function
                         | [] ->
                             (eprintf
                                "No level labelled \"%s\" in entry \"%s\"\n"
                                n entry.ename;
                              flush stderr;
                              failwith "Grammar.extend")
                         | lev :: levs ->
                             if Tools.is_level_labelled n lev
                             then ([ lev ], empty_lev, levs)
                             else
                               (let (levs1, rlev, levs2) = get levs
                                in ((lev :: levs1), rlev, levs2)))
                      in get levs
                  | None ->
                      (match levs with
                       | lev :: levs ->
                           ([], (change_lev entry lev "<top>"), levs)
                       | [] -> ([], empty_lev, []))
                let rec check_gram entry =
                  function
                  | Snterm e ->
                      if e.egram != entry.egram
                      then
                        (eprintf
                           "\
  Error: entries \"%s\" and \"%s\" do not belong to the same grammar.\n"
                           entry.ename e.ename;
                         flush stderr;
                         failwith "Grammar.extend error")
                      else ()
                  | Snterml (e, _) ->
                      if e.egram != entry.egram
                      then
                        (eprintf
                           "\
  Error: entries \"%s\" and \"%s\" do not belong to the same grammar.\n"
                           entry.ename e.ename;
                         flush stderr;
                         failwith "Grammar.extend error")
                      else ()
                  | Smeta (_, sl, _) -> List.iter (check_gram entry) sl
                  | Slist0sep (s, t) ->
                      (check_gram entry t; check_gram entry s)
                  | Slist1sep (s, t) ->
                      (check_gram entry t; check_gram entry s)
                  | Slist0 s -> check_gram entry s
                  | Slist1 s -> check_gram entry s
                  | Sopt s -> check_gram entry s
                  | Stree t -> tree_check_gram entry t
                  | Snext | Sself | Stoken _ | Skeyword _ -> ()
                and tree_check_gram entry =
                  function
                  | Node { node = n; brother = bro; son = son } ->
                      (check_gram entry n;
                       tree_check_gram entry bro;
                       tree_check_gram entry son)
                  | LocAct (_, _) | DeadEnd -> ()
                let get_initial =
                  function
                  | Sself :: symbols -> (true, symbols)
                  | symbols -> (false, symbols)
                let insert_tokens gram symbols =
                  let rec insert =
                    function
                    | Smeta (_, sl, _) -> List.iter insert sl
                    | Slist0 s -> insert s
                    | Slist1 s -> insert s
                    | Slist0sep (s, t) -> (insert s; insert t)
                    | Slist1sep (s, t) -> (insert s; insert t)
                    | Sopt s -> insert s
                    | Stree t -> tinsert t
                    | Skeyword kwd -> using gram kwd
                    | Snterm _ | Snterml (_, _) | Snext | Sself | Stoken _ ->
                        ()
                  and tinsert =
                    function
                    | Node { node = s; brother = bro; son = son } ->
                        (insert s; tinsert bro; tinsert son)
                    | LocAct (_, _) | DeadEnd -> ()
                  in List.iter insert symbols
                let insert_tree entry gsymbols action tree =
                  let rec insert symbols tree =
                    match symbols with
                    | s :: sl -> insert_in_tree s sl tree
                    | [] ->
                        (match tree with
                         | Node { node = s; son = son; brother = bro } ->
                             Node
                               {
                                 
                                 node = s;
                                 son = son;
                                 brother = insert [] bro;
                               }
                         | LocAct (old_action, action_list) ->
                             let () =
                               if !(entry.egram.warning_verbose)
                               then
                                 eprintf
                                   "<W> Grammar extension: in [%s] some rule has been masked@."
                                   entry.ename
                               else ()
                             in LocAct (action, old_action :: action_list)
                         | DeadEnd -> LocAct (action, []))
                  and insert_in_tree s sl tree =
                    match try_insert s sl tree with
                    | Some t -> t
                    | None ->
                        Node
                          {
                            
                            node = s;
                            son = insert sl DeadEnd;
                            brother = tree;
                          }
                  and try_insert s sl tree =
                    match tree with
                    | Node { node = s1; son = son; brother = bro } ->
                        if Tools.eq_symbol s s1
                        then
                          (let t =
                             Node
                               {
                                 
                                 node = s1;
                                 son = insert sl son;
                                 brother = bro;
                               }
                           in Some t)
                        else
                          if
                            (is_before s1 s) ||
                              ((derive_eps s) && (not (derive_eps s1)))
                          then
                            (let bro =
                               match try_insert s sl bro with
                               | Some bro -> bro
                               | None ->
                                   Node
                                     {
                                       
                                       node = s;
                                       son = insert sl DeadEnd;
                                       brother = bro;
                                     } in
                             let t =
                               Node {  node = s1; son = son; brother = bro; }
                             in Some t)
                          else
                            (match try_insert s sl bro with
                             | Some bro ->
                                 let t =
                                   Node
                                     {  node = s1; son = son; brother = bro;
                                     }
                                 in Some t
                             | None -> None)
                    | LocAct (_, _) | DeadEnd -> None
                  and insert_new =
                    function
                    | s :: sl ->
                        Node
                          {
                            
                            node = s;
                            son = insert_new sl;
                            brother = DeadEnd;
                          }
                    | [] -> LocAct (action, [])
                  in insert gsymbols tree
                let insert_level entry e1 symbols action slev =
                  match e1 with
                  | true ->
                      {
                        
                        assoc = slev.assoc;
                        lname = slev.lname;
                        lsuffix =
                          insert_tree entry symbols action slev.lsuffix;
                        lprefix = slev.lprefix;
                      }
                  | false ->
                      {
                        
                        assoc = slev.assoc;
                        lname = slev.lname;
                        lsuffix = slev.lsuffix;
                        lprefix =
                          insert_tree entry symbols action slev.lprefix;
                      }
                let levels_of_rules entry position rules =
                  let elev =
                    match entry.edesc with
                    | Dlevels elev -> elev
                    | Dparser _ ->
                        (eprintf "Error: entry not extensible: \"%s\"\n"
                           entry.ename;
                         flush stderr;
                         failwith "Grammar.extend")
                  in
                    if rules = []
                    then elev
                    else
                      (let (levs1, make_lev, levs2) =
                         get_level entry position elev in
                       let (levs, _) =
                         List.fold_left
                           (fun (levs, make_lev) (lname, assoc, level) ->
                              let lev = make_lev lname assoc in
                              let lev =
                                List.fold_left
                                  (fun lev (symbols, action) ->
                                     let symbols =
                                       List.map (change_to_self entry)
                                         symbols
                                     in
                                       (List.iter (check_gram entry) symbols;
                                        let (e1, symbols) =
                                          get_initial symbols
                                        in
                                          (insert_tokens entry.egram symbols;
                                           insert_level entry e1 symbols
                                             action lev)))
                                  lev level
                              in ((lev :: levs), empty_lev))
                           ([], make_lev) rules
                       in levs1 @ ((List.rev levs) @ levs2))
                let extend entry (position, rules) =
                  let elev = levels_of_rules entry position rules
                  in
                    (entry.edesc <- Dlevels elev;
                     entry.estart <-
                       (fun lev c strm ->
                          let f = Parser.start_parser_of_entry entry
                          in (entry.estart <- f; f lev c strm));
                     entry.econtinue <-
                       fun lev bp a c strm ->
                         let f = Parser.continue_parser_of_entry entry
                         in (entry.econtinue <- f; f lev bp a c strm))
              end
          end
        module Delete =
          struct
            module Make (Structure : Structure.S) =
              struct
                module Tools = Tools.Make(Structure)
                module Parser = Parser.Make(Structure)
                open Structure
                let delete_rule_in_tree entry =
                  let rec delete_in_tree symbols tree =
                    match (symbols, tree) with
                    | (s :: sl, Node n) ->
                        if Tools.logically_eq_symbols entry s n.node
                        then delete_son sl n
                        else
                          (match delete_in_tree symbols n.brother with
                           | Some ((dsl, t)) ->
                               Some
                                 ((dsl,
                                   (Node
                                      {
                                        
                                        node = n.node;
                                        son = n.son;
                                        brother = t;
                                      })))
                           | None -> None)
                    | (_ :: _, _) -> None
                    | ([], Node n) ->
                        (match delete_in_tree [] n.brother with
                         | Some ((dsl, t)) ->
                             Some
                               ((dsl,
                                 (Node
                                    {
                                      
                                      node = n.node;
                                      son = n.son;
                                      brother = t;
                                    })))
                         | None -> None)
                    | ([], DeadEnd) -> None
                    | ([], LocAct (_, [])) -> Some (((Some []), DeadEnd))
                    | ([], LocAct (_, (action :: list))) ->
                        Some ((None, (LocAct (action, list))))
                  and delete_son sl n =
                    match delete_in_tree sl n.son with
                    | Some ((Some dsl, DeadEnd)) ->
                        Some (((Some (n.node :: dsl)), (n.brother)))
                    | Some ((Some dsl, t)) ->
                        let t =
                          Node
                            {  node = n.node; son = t; brother = n.brother; }
                        in Some (((Some (n.node :: dsl)), t))
                    | Some ((None, t)) ->
                        let t =
                          Node
                            {  node = n.node; son = t; brother = n.brother; }
                        in Some ((None, t))
                    | None -> None
                  in delete_in_tree
                let rec decr_keyw_use gram =
                  function
                  | Skeyword kwd -> removing gram kwd
                  | Smeta (_, sl, _) -> List.iter (decr_keyw_use gram) sl
                  | Slist0 s -> decr_keyw_use gram s
                  | Slist1 s -> decr_keyw_use gram s
                  | Slist0sep (s1, s2) ->
                      (decr_keyw_use gram s1; decr_keyw_use gram s2)
                  | Slist1sep (s1, s2) ->
                      (decr_keyw_use gram s1; decr_keyw_use gram s2)
                  | Sopt s -> decr_keyw_use gram s
                  | Stree t -> decr_keyw_use_in_tree gram t
                  | Sself | Snext | Snterm _ | Snterml (_, _) | Stoken _ ->
                      ()
                and decr_keyw_use_in_tree gram =
                  function
                  | DeadEnd | LocAct (_, _) -> ()
                  | Node n ->
                      (decr_keyw_use gram n.node;
                       decr_keyw_use_in_tree gram n.son;
                       decr_keyw_use_in_tree gram n.brother)
                let rec delete_rule_in_suffix entry symbols =
                  function
                  | lev :: levs ->
                      (match delete_rule_in_tree entry symbols lev.lsuffix
                       with
                       | Some ((dsl, t)) ->
                           ((match dsl with
                             | Some dsl ->
                                 List.iter (decr_keyw_use entry.egram) dsl
                             | None -> ());
                            (match t with
                             | DeadEnd when lev.lprefix == DeadEnd -> levs
                             | _ ->
                                 let lev =
                                   {
                                     
                                     assoc = lev.assoc;
                                     lname = lev.lname;
                                     lsuffix = t;
                                     lprefix = lev.lprefix;
                                   }
                                 in lev :: levs))
                       | None ->
                           let levs =
                             delete_rule_in_suffix entry symbols levs
                           in lev :: levs)
                  | [] -> raise Not_found
                let rec delete_rule_in_prefix entry symbols =
                  function
                  | lev :: levs ->
                      (match delete_rule_in_tree entry symbols lev.lprefix
                       with
                       | Some ((dsl, t)) ->
                           ((match dsl with
                             | Some dsl ->
                                 List.iter (decr_keyw_use entry.egram) dsl
                             | None -> ());
                            (match t with
                             | DeadEnd when lev.lsuffix == DeadEnd -> levs
                             | _ ->
                                 let lev =
                                   {
                                     
                                     assoc = lev.assoc;
                                     lname = lev.lname;
                                     lsuffix = lev.lsuffix;
                                     lprefix = t;
                                   }
                                 in lev :: levs))
                       | None ->
                           let levs =
                             delete_rule_in_prefix entry symbols levs
                           in lev :: levs)
                  | [] -> raise Not_found
                let rec delete_rule_in_level_list entry symbols levs =
                  match symbols with
                  | Sself :: symbols ->
                      delete_rule_in_suffix entry symbols levs
                  | Snterm e :: symbols when e == entry ->
                      delete_rule_in_suffix entry symbols levs
                  | _ -> delete_rule_in_prefix entry symbols levs
                let delete_rule entry sl =
                  match entry.edesc with
                  | Dlevels levs ->
                      let levs = delete_rule_in_level_list entry sl levs
                      in
                        (entry.edesc <- Dlevels levs;
                         entry.estart <-
                           (fun lev c strm ->
                              let f = Parser.start_parser_of_entry entry
                              in (entry.estart <- f; f lev c strm));
                         entry.econtinue <-
                           (fun lev bp a c strm ->
                              let f = Parser.continue_parser_of_entry entry
                              in (entry.econtinue <- f; f lev bp a c strm)))
                  | Dparser _ -> ()
              end
          end
        module Fold :
          sig
            module Make (Structure : Structure.S) :
              sig
                open Structure
                val sfold0 : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) fold
                val sfold1 : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) fold
                val sfold0sep : ('a -> 'b -> 'b) -> 'b -> (_, 'a, 'b) foldsep
              end
          end =
          struct
            module Make (Structure : Structure.S) =
              struct
                open Structure
                open Format
                module Parse = Parser.Make(Structure)
                module Fail = Failed.Make(Structure)
                open Sig.Grammar
                module Stream =
                  struct
                    include Stream
                    let junk strm = Context.junk strm
                    let count strm = Context.bp strm
                  end
                let sfold0 f e _entry _symbl psymb =
                  let rec fold accu (__strm : _ Stream.t) =
                    match try Some (psymb __strm)
                          with | Stream.Failure -> None
                    with
                    | Some a -> fold (f a accu) __strm
                    | _ -> accu
                  in fun (__strm : _ Stream.t) -> fold e __strm
                let sfold1 f e _entry _symbl psymb =
                  let rec fold accu (__strm : _ Stream.t) =
                    match try Some (psymb __strm)
                          with | Stream.Failure -> None
                    with
                    | Some a -> fold (f a accu) __strm
                    | _ -> accu
                  in
                    fun (__strm : _ Stream.t) ->
                      let a = psymb __strm
                      in
                        try fold (f a e) __strm
                        with | Stream.Failure -> raise (Stream.Error "")
                let sfold0sep f e entry symbl psymb psep =
                  let failed =
                    function
                    | [ symb; sep ] -> Fail.symb_failed_txt entry sep symb
                    | _ -> "failed" in
                  let rec kont accu (__strm : _ Stream.t) =
                    match try Some (psep __strm)
                          with | Stream.Failure -> None
                    with
                    | Some () ->
                        let a =
                          (try psymb __strm
                           with
                           | Stream.Failure ->
                               raise (Stream.Error (failed symbl)))
                        in kont (f a accu) __strm
                    | _ -> accu
                  in
                    fun (__strm : _ Stream.t) ->
                      match try Some (psymb __strm)
                            with | Stream.Failure -> None
                      with
                      | Some a -> kont (f a e) __strm
                      | _ -> e
                let sfold1sep f e entry symbl psymb psep =
                  let failed =
                    function
                    | [ symb; sep ] -> Fail.symb_failed_txt entry sep symb
                    | _ -> "failed" in
                  let parse_top =
                    function
                    | [ symb; _ ] -> Parse.parse_top_symb entry symb
                    | _ -> raise Stream.Failure in
                  let rec kont accu (__strm : _ Stream.t) =
                    match try Some (psep __strm)
                          with | Stream.Failure -> None
                    with
                    | Some () ->
                        let a =
                          (try
                             try psymb __strm
                             with
                             | Stream.Failure ->
                                 let a =
                                   (try parse_top symbl __strm
                                    with
                                    | Stream.Failure ->
                                        raise (Stream.Error (failed symbl)))
                                 in Obj.magic a
                           with | Stream.Failure -> raise (Stream.Error ""))
                        in kont (f a accu) __strm
                    | _ -> accu
                  in
                    fun (__strm : _ Stream.t) ->
                      let a = psymb __strm in kont (f a e) __strm
              end
          end
        module Entry =
          struct
            module Make (Structure : Structure.S) =
              struct
                module Dump = Print.MakeDump(Structure)
                module Print = Print.Make(Structure)
                module Tools = Tools.Make(Structure)
                open Format
                open Structure
                type 'a t = internal_entry
                let name e = e.ename
                let print ppf e = fprintf ppf "%a@\n" Print.entry e
                let dump ppf e = fprintf ppf "%a@\n" Dump.entry e
                let mk g n =
                  {
                    
                    egram = g;
                    ename = n;
                    estart = Tools.empty_entry n;
                    econtinue =
                      (fun _ _ _ _ (__strm : _ Stream.t) ->
                         raise Stream.Failure);
                    edesc = Dlevels [];
                  }
                let action_parse entry ts : Action.t =
                  Context.call_with_ctx ts
                    (fun c ->
                       try entry.estart 0 c (Context.stream c)
                       with
                       | Stream.Failure ->
                           Loc.raise (Context.loc_ep c)
                             (Stream.Error
                                ("illegal begin of " ^ entry.ename))
                       | (Loc.Exc_located (_, _) as exc) -> raise exc
                       | exc -> Loc.raise (Context.loc_ep c) exc)
                let lex entry loc cs = entry.egram.glexer loc cs
                let lex_string entry loc str =
                  lex entry loc (Stream.of_string str)
                let filter entry ts =
                  Token.Filter.filter (get_filter entry.egram) ts
                let parse_tokens_after_filter entry ts =
                  Action.get (action_parse entry ts)
                let parse_tokens_before_filter entry ts =
                  parse_tokens_after_filter entry (filter entry ts)
                let parse entry loc cs =
                  parse_tokens_before_filter entry (lex entry loc cs)
                let parse_string entry loc str =
                  parse_tokens_before_filter entry (lex_string entry loc str)
                let of_parser g n (p : (Token.t * Loc.t) Stream.t -> 'a) :
                  'a t =
                  {
                    
                    egram = g;
                    ename = n;
                    estart = (fun _ _ ts -> Action.mk (p ts));
                    econtinue =
                      (fun _ _ _ _ (__strm : _ Stream.t) ->
                         raise Stream.Failure);
                    edesc = Dparser (fun ts -> Action.mk (p ts));
                  }
                let setup_parser e (p : (Token.t * Loc.t) Stream.t -> 'a) =
                  let f ts = Action.mk (p ts)
                  in
                    (e.estart <- (fun _ _ -> f);
                     e.econtinue <-
                       (fun _ _ _ _ (__strm : _ Stream.t) ->
                          raise Stream.Failure);
                     e.edesc <- Dparser f)
                let clear e =
                  (e.estart <-
                     (fun _ _ (__strm : _ Stream.t) -> raise Stream.Failure);
                   e.econtinue <-
                     (fun _ _ _ _ (__strm : _ Stream.t) ->
                        raise Stream.Failure);
                   e.edesc <- Dlevels [])
                let obj x = x
              end
          end
        module Static =
          struct
            module Make (Lexer : Sig.Lexer) :
              Sig.Grammar.Static with module Loc = Lexer.Loc
              and module Token = Lexer.Token =
              struct
                module Structure = Structure.Make(Lexer)
                module Delete = Delete.Make(Structure)
                module Insert = Insert.Make(Structure)
                module Fold = Fold.Make(Structure)
                include Structure
                let gram =
                  let gkeywords = Hashtbl.create 301
                  in
                    {
                      
                      gkeywords = gkeywords;
                      gfilter = Token.Filter.mk (Hashtbl.mem gkeywords);
                      glexer = Lexer.mk ();
                      warning_verbose = ref true;
                      error_verbose = Camlp4_config.verbose;
                    }
                module Entry =
                  struct
                    module E = Entry.Make(Structure)
                    type 'a t = 'a E.t
                    let mk = E.mk gram
                    let of_parser name strm = E.of_parser gram name strm
                    let setup_parser = E.setup_parser
                    let name = E.name
                    let print = E.print
                    let clear = E.clear
                    let dump = E.dump
                    let obj x = x
                  end
                let get_filter () = gram.gfilter
                let lex loc cs = gram.glexer loc cs
                let lex_string loc str = lex loc (Stream.of_string str)
                let filter ts = Token.Filter.filter gram.gfilter ts
                let parse_tokens_after_filter entry ts =
                  Entry.E.parse_tokens_after_filter entry ts
                let parse_tokens_before_filter entry ts =
                  parse_tokens_after_filter entry (filter ts)
                let parse entry loc cs =
                  parse_tokens_before_filter entry (lex loc cs)
                let parse_string entry loc str =
                  parse_tokens_before_filter entry (lex_string loc str)
                let delete_rule = Delete.delete_rule
                let srules e rl =
                  let t =
                    List.fold_left
                      (fun tree (symbols, action) ->
                         Insert.insert_tree e symbols action tree)
                      DeadEnd rl
                  in Stree t
                let sfold0 = Fold.sfold0
                let sfold1 = Fold.sfold1
                let sfold0sep = Fold.sfold0sep
                let extend = Insert.extend
              end
          end
        module Dynamic =
          struct
            module Make (Lexer : Sig.Lexer) :
              Sig.Grammar.Dynamic with module Loc = Lexer.Loc
              and module Token = Lexer.Token =
              struct
                module Structure = Structure.Make(Lexer)
                module Delete = Delete.Make(Structure)
                module Insert = Insert.Make(Structure)
                module Entry = Entry.Make(Structure)
                module Fold = Fold.Make(Structure)
                include Structure
                let mk () =
                  let gkeywords = Hashtbl.create 301
                  in
                    {
                      
                      gkeywords = gkeywords;
                      gfilter = Token.Filter.mk (Hashtbl.mem gkeywords);
                      glexer = Lexer.mk ();
                      warning_verbose = ref true;
                      error_verbose = Camlp4_config.verbose;
                    }
                let get_filter g = g.gfilter
                let lex g loc cs = g.glexer loc cs
                let lex_string g loc str = lex g loc (Stream.of_string str)
                let filter g ts = Token.Filter.filter g.gfilter ts
                let parse_tokens_after_filter entry ts =
                  Entry.parse_tokens_after_filter entry ts
                let parse_tokens_before_filter entry ts =
                  parse_tokens_after_filter entry (filter entry.egram ts)
                let parse entry loc cs =
                  parse_tokens_before_filter entry (lex entry.egram loc cs)
                let parse_string entry loc str =
                  parse_tokens_before_filter entry
                    (lex_string entry.egram loc str)
                let delete_rule = Delete.delete_rule
                let srules e rl =
                  let t =
                    List.fold_left
                      (fun tree (symbols, action) ->
                         Insert.insert_tree e symbols action tree)
                      DeadEnd rl
                  in Stree t
                let sfold0 = Fold.sfold0
                let sfold1 = Fold.sfold1
                let sfold0sep = Fold.sfold0sep
                let extend = Insert.extend
              end
          end
      end
  end
module Printers =
  struct
    module DumpCamlp4Ast :
      sig
        module Id : Sig.Id
        module Make (Syntax : Sig.Syntax) :
          Sig.Printer with module Ast = Syntax.Ast
      end =
      struct
        module Id =
          struct
            let name = "Camlp4Printers.DumpCamlp4Ast"
            let version =
              "$Id: DumpCamlp4Ast.ml,v 1.4 2006/10/03 08:54:08 ertai Exp $"
          end
        module Make (Syntax : Sig.Syntax) :
          Sig.Printer with module Ast = Syntax.Ast =
          struct
            include Syntax
            let with_open_out_file x f =
              match x with
              | Some file ->
                  let oc = open_out_bin file
                  in (f oc; flush oc; close_out oc)
              | None ->
                  (set_binary_mode_out stdout true; f stdout; flush stdout)
            let dump_ast magic ast oc =
              (output_string oc magic; output_value oc ast)
            let print_interf ?input_file:(_) ?output_file ast =
              with_open_out_file output_file
                (dump_ast Camlp4_config.camlp4_ast_intf_magic_number ast)
            let print_implem ?input_file:(_) ?output_file ast =
              with_open_out_file output_file
                (dump_ast Camlp4_config.camlp4_ast_impl_magic_number ast)
          end
      end
    module DumpOCamlAst :
      sig
        module Id : Sig.Id
        module Make (Syntax : Sig.Camlp4Syntax) :
          Sig.Printer with module Ast = Syntax.Ast
      end =
      struct
        module Id : Sig.Id =
          struct
            let name = "Camlp4Printers.DumpOCamlAst"
            let version =
              "$Id: DumpOCamlAst.ml,v 1.4 2006/10/03 08:54:08 ertai Exp $"
          end
        module Make (Syntax : Sig.Camlp4Syntax) :
          Sig.Printer with module Ast = Syntax.Ast =
          struct
            include Syntax
            module Ast2pt = Struct.Camlp4Ast2OCamlAst.Make(Ast)
            let with_open_out_file x f =
              match x with
              | Some file ->
                  let oc = open_out_bin file
                  in (f oc; flush oc; close_out oc)
              | None ->
                  (set_binary_mode_out stdout true; f stdout; flush stdout)
            let dump_pt magic fname pt oc =
              (output_string oc magic;
               output_value oc (if fname = "-" then "" else fname);
               output_value oc pt)
            let print_interf ?(input_file = "-") ?output_file ast =
              let pt = Ast2pt.sig_item ast
              in
                with_open_out_file output_file
                  (dump_pt Camlp4_config.ocaml_ast_intf_magic_number
                     input_file pt)
            let print_implem ?(input_file = "-") ?output_file ast =
              let pt = Ast2pt.str_item ast
              in
                with_open_out_file output_file
                  (dump_pt Camlp4_config.ocaml_ast_impl_magic_number
                     input_file pt)
          end
      end
    module Null :
      sig
        module Id : Sig.Id
        module Make (Syntax : Sig.Syntax) :
          Sig.Printer with module Ast = Syntax.Ast
      end =
      struct
        module Id =
          struct
            let name = "Camlp4.Printers.Null"
            let version =
              "$Id: Null.ml,v 1.1 2006/10/03 08:54:08 ertai Exp $"
          end
        module Make (Syntax : Sig.Syntax) =
          struct
            include Syntax
            let print_interf ?input_file:(_) ?output_file:(_) _ = ()
            let print_implem ?input_file:(_) ?output_file:(_) _ = ()
          end
      end
    module OCaml :
      sig
        module Id : Sig.Id
        module Make (Syntax : Sig.Camlp4Syntax) :
          sig
            open Format
            include Sig.Camlp4Syntax with module Loc = Syntax.Loc
              and module Warning = Syntax.Warning
              and module Token = Syntax.Token and module Ast = Syntax.Ast
              and module Gram = Syntax.Gram
            val list' :
              (formatter -> 'a -> unit) ->
                ('b, formatter, unit) format ->
                  (unit, formatter, unit) format ->
                    formatter -> 'a list -> unit
            val list :
              (formatter -> 'a -> unit) ->
                ('b, formatter, unit) format -> formatter -> 'a list -> unit
            val lex_string : string -> Token.t
            val is_infix : string -> bool
            val is_keyword : string -> bool
            val ocaml_char : string -> string
            val get_expr_args :
              Ast.expr -> Ast.expr list -> (Ast.expr * (Ast.expr list))
            val get_patt_args :
              Ast.patt -> Ast.patt list -> (Ast.patt * (Ast.patt list))
            val get_ctyp_args :
              Ast.ctyp -> Ast.ctyp list -> (Ast.ctyp * (Ast.ctyp list))
            val expr_fun_args : Ast.expr -> ((Ast.patt list) * Ast.expr)
            class printer :
              ?curry_constr: bool ->
                ?comments: bool ->
                  unit ->
                    object ('a)
                      method interf : formatter -> Ast.sig_item -> unit
                      method implem : formatter -> Ast.str_item -> unit
                      method sig_item : formatter -> Ast.sig_item -> unit
                      method str_item : formatter -> Ast.str_item -> unit
                      val pipe : bool
                      val semi : bool
                      val semisep : string
                      val value_val : string
                      val value_let : string
                      method anti : formatter -> string -> unit
                      method class_declaration :
                        formatter -> Ast.class_expr -> unit
                      method class_expr : formatter -> Ast.class_expr -> unit
                      method class_sig_item :
                        formatter -> Ast.class_sig_item -> unit
                      method class_str_item :
                        formatter -> Ast.class_str_item -> unit
                      method class_type : formatter -> Ast.class_type -> unit
                      method constrain :
                        formatter -> (Ast.ctyp * Ast.ctyp) -> unit
                      method ctyp : formatter -> Ast.ctyp -> unit
                      method ctyp1 : formatter -> Ast.ctyp -> unit
                      method constructor_type : formatter -> Ast.ctyp -> unit
                      method dot_expr : formatter -> Ast.expr -> unit
                      method expr : formatter -> Ast.expr -> unit
                      method expr_list : formatter -> Ast.expr list -> unit
                      method expr_list_cons :
                        bool -> formatter -> Ast.expr -> unit
                      method functor_arg :
                        formatter -> (string * Ast.module_type) -> unit
                      method functor_args :
                        formatter -> (string * Ast.module_type) list -> unit
                      method ident : formatter -> Ast.ident -> unit
                      method intlike : formatter -> string -> unit
                      method binding : formatter -> Ast.binding -> unit
                      method record_binding :
                        formatter -> Ast.binding -> unit
                      method match_case : formatter -> Ast.match_case -> unit
                      method match_case_aux :
                        formatter -> Ast.match_case -> unit
                      method mk_expr_list :
                        Ast.expr -> ((Ast.expr list) * (Ast.expr option))
                      method mk_patt_list :
                        Ast.patt -> ((Ast.patt list) * (Ast.patt option))
                      method module_expr :
                        formatter -> Ast.module_expr -> unit
                      method module_expr_get_functor_args :
                        (string * Ast.module_type) list ->
                          Ast.module_expr ->
                            (((string * Ast.module_type) list) * Ast.
                             module_expr * (Ast.module_type option))
                      method module_rec_binding :
                        formatter -> Ast.module_binding -> unit
                      method module_type :
                        formatter -> Ast.module_type -> unit
                      method mutable_flag :
                        formatter -> Ast.meta_bool -> unit
                      method direction_flag :
                        formatter -> Ast.meta_bool -> unit
                      method rec_flag : formatter -> Ast.meta_bool -> unit
                      method flag :
                        formatter -> Ast.meta_bool -> string -> unit
                      method node : formatter -> 'b -> ('b -> Loc.t) -> unit
                      method object_dup :
                        formatter -> (string * Ast.expr) list -> unit
                      method patt : formatter -> Ast.patt -> unit
                      method patt1 : formatter -> Ast.patt -> unit
                      method patt2 : formatter -> Ast.patt -> unit
                      method patt3 : formatter -> Ast.patt -> unit
                      method patt4 : formatter -> Ast.patt -> unit
                      method patt5 : formatter -> Ast.patt -> unit
                      method patt_expr_fun_args :
                        formatter -> (Ast.patt * Ast.expr) -> unit
                      method patt_class_expr_fun_args :
                        formatter -> (Ast.patt * Ast.class_expr) -> unit
                      method print_comments_before :
                        Loc.t -> formatter -> unit
                      method private_flag :
                        formatter -> Ast.meta_bool -> unit
                      method virtual_flag :
                        formatter -> Ast.meta_bool -> unit
                      method quoted_string : formatter -> string -> unit
                      method raise_match_failure : formatter -> Loc.t -> unit
                      method reset : 'a
                      method reset_semi : 'a
                      method semisep : string
                      method set_comments : bool -> 'a
                      method set_curry_constr : bool -> 'a
                      method set_loc_and_comments : 'a
                      method set_semisep : string -> 'a
                      method simple_ctyp : formatter -> Ast.ctyp -> unit
                      method simple_expr : formatter -> Ast.expr -> unit
                      method simple_patt : formatter -> Ast.patt -> unit
                      method seq : formatter -> Ast.expr -> unit
                      method string : formatter -> string -> unit
                      method sum_type : formatter -> Ast.ctyp -> unit
                      method type_params : formatter -> Ast.ctyp list -> unit
                      method class_params : formatter -> Ast.ctyp -> unit
                      method under_pipe : 'a
                      method under_semi : 'a
                      method var : formatter -> string -> unit
                      method with_constraint :
                        formatter -> Ast.with_constr -> unit
                    end
            val with_outfile :
              string option -> (formatter -> 'a -> unit) -> 'a -> unit
            val print :
              string option ->
                (printer -> formatter -> 'a -> unit) -> 'a -> unit
            val print_interf :
              ?input_file: string ->
                ?output_file: string -> Ast.sig_item -> unit
            val print_implem :
              ?input_file: string ->
                ?output_file: string -> Ast.str_item -> unit
          end
        module MakeMore (Syntax : Sig.Camlp4Syntax) :
          Sig.Printer with module Ast = Syntax.Ast
      end =
      struct
        open Format
        module Id =
          struct
            let name = "Camlp4.Printers.OCaml"
            let version =
              "$Id: OCaml.ml,v 1.19 2006/10/10 22:32:43 ertai Exp $"
          end
        module Make (Syntax : Sig.Camlp4Syntax) =
          struct
            include Syntax
            let pp = fprintf
            let cut f = fprintf f "@ "
            let list' elt sep sep' f =
              let rec loop =
                function
                | [] -> ()
                | x :: xs -> (pp f sep; elt f x; pp f sep'; loop xs)
              in
                function
                | [] -> ()
                | [ x ] -> (elt f x; pp f sep')
                | x :: xs -> (elt f x; pp f sep'; loop xs)
            let list elt sep f =
              let rec loop =
                function | [] -> () | x :: xs -> (pp f sep; elt f x; loop xs)
              in
                function
                | [] -> ()
                | [ x ] -> elt f x
                | x :: xs -> (elt f x; loop xs)
            module CommentFilter = Struct.CommentFilter.Make(Token)
            let comment_filter = CommentFilter.mk ()
            let _ = CommentFilter.define (Gram.get_filter ()) comment_filter
            module StringSet = Set.Make(String)
            let is_infix =
              let infixes =
                List.fold_right StringSet.add
                  [ "=="; "!="; "+"; "-"; "+."; "-."; "*"; "*."; "/"; "/.";
                    "**"; "="; "<>"; "<"; ">"; "<="; ">="; "^"; "^^"; "@";
                    "&&"; "||"; "asr"; "land"; "lor"; "lsl"; "lsr"; "lxor";
                    "mod"; "or" ]
                  StringSet.empty
              in fun s -> StringSet.mem s infixes
            let is_keyword =
              let keywords =
                List.fold_right StringSet.add
                  [ "and"; "as"; "assert"; "asr"; "begin"; "class";
                    "constraint"; "do"; "done"; "downto"; "else"; "end";
                    "exception"; "external"; "false"; "for"; "fun";
                    "function"; "functor"; "if"; "in"; "include"; "inherit";
                    "initializer"; "land"; "lazy"; "let"; "lor"; "lsl";
                    "lsr"; "lxor"; "match"; "method"; "mod"; "module";
                    "mutable"; "new"; "object"; "of"; "open"; "or"; "parser";
                    "private"; "rec"; "sig"; "struct"; "then"; "to"; "true";
                    "try"; "type"; "val"; "virtual"; "when"; "while"; "with" ]
                  StringSet.empty
              in fun s -> StringSet.mem s keywords
            module Lexer = Struct.Lexer.Make(Token)
            let _ = let module M = ErrorHandler.Register(Lexer.Error) in ()
            open Sig
            let lexer s =
              Lexer.from_string ~quotations: !Camlp4_config.quotations Loc.
                ghost s
            let lex_string str =
              try
                let (__strm : _ Stream.t) = lexer str
                in
                  match Stream.peek __strm with
                  | Some ((tok, _)) ->
                      (Stream.junk __strm;
                       (match Stream.peek __strm with
                        | Some ((EOI, _)) -> (Stream.junk __strm; tok)
                        | _ -> raise (Stream.Error "")))
                  | _ -> raise Stream.Failure
              with
              | Stream.Failure ->
                  failwith
                    (sprintf
                       "Cannot print %S this string contains more than one token"
                       str)
              | Lexer.Error.E exn ->
                  failwith
                    (sprintf
                       "Cannot print %S this identifier does not respect OCaml lexing rules (%s)"
                       str (Lexer.Error.to_string exn))
            let ocaml_char = function | "'" -> "\\'" | c -> c
            let rec get_expr_args a al =
              match a with
              | Ast.ExApp (_, a1, a2) -> get_expr_args a1 (a2 :: al)
              | _ -> (a, al)
            let rec get_patt_args a al =
              match a with
              | Ast.PaApp (_, a1, a2) -> get_patt_args a1 (a2 :: al)
              | _ -> (a, al)
            let rec get_ctyp_args a al =
              match a with
              | Ast.TyApp (_, a1, a2) -> get_ctyp_args a1 (a2 :: al)
              | _ -> (a, al)
            let is_irrefut_patt = Ast.is_irrefut_patt
            let rec expr_fun_args =
              function
              | (Ast.ExFun (_, (Ast.McArr (_, p, (Ast.ExNil _), e))) as ge)
                  ->
                  if is_irrefut_patt p
                  then (let (pl, e) = expr_fun_args e in ((p :: pl), e))
                  else ([], ge)
              | ge -> ([], ge)
            let rec class_expr_fun_args =
              function
              | (Ast.CeFun (_, p, ce) as ge) ->
                  if is_irrefut_patt p
                  then
                    (let (pl, ce) = class_expr_fun_args ce in ((p :: pl), ce))
                  else ([], ge)
              | ge -> ([], ge)
            let rec do_print_comments_before loc f (__strm : _ Stream.t) =
              match Stream.peek __strm with
              | Some ((comm, comm_loc)) when Loc.strictly_before comm_loc loc
                  ->
                  (Stream.junk __strm;
                   let s = __strm in
                   let () = f comm comm_loc
                   in do_print_comments_before loc f s)
              | _ -> ()
            class printer ?curry_constr:(init_curry_constr = false)
                    ?(comments = true) () =
              object (o)
                val pipe = false
                val semi = false
                method under_pipe = {<  pipe = true; >}
                method under_semi = {<  semi = true; >}
                method reset_semi = {<  semi = false; >}
                method reset = {<  pipe = false; semi = false; >}
                val semisep = ";;"
                val andsep =
                  ("@]@ @[<2>and@ " : (unit, formatter, unit) format)
                val value_val = "val"
                val value_let = "let"
                val mode = if comments then `comments else `no_comments
                val curry_constr = init_curry_constr
                val var_conversion = false
                method semisep = semisep
                method set_semisep = fun s -> {<  semisep = s; >}
                method set_comments =
                  fun b ->
                    {<  mode = if b then `comments else `no_comments; >}
                method set_loc_and_comments =
                  {<  mode = `loc_and_comments; >}
                method set_curry_constr = fun b -> {<  curry_constr = b; >}
                method print_comments_before =
                  fun loc f ->
                    match mode with
                    | `comments ->
                        do_print_comments_before loc
                          (fun c _ -> pp f "%s@ " c)
                          (CommentFilter.take_stream comment_filter)
                    | `loc_and_comments ->
                        let () = pp f "(*loc: %a*)@ " Loc.dump loc
                        in
                          do_print_comments_before loc
                            (fun s -> pp f "%s(*comm_loc: %a*)@ " s Loc.dump)
                            (CommentFilter.take_stream comment_filter)
                    | _ -> ()
                method var =
                  fun f ->
                    function
                    | "" -> pp f "$lid:\"\"$"
                    | "[]" -> pp f "[]"
                    | "()" -> pp f "()"
                    | " True" -> pp f "True"
                    | " False" -> pp f "False"
                    | v ->
                        (match (var_conversion, v) with
                         | (true, "val") -> pp f "contents"
                         | (true, "True") -> pp f "true"
                         | (true, "False") -> pp f "false"
                         | _ ->
                             (match lex_string v with
                              | LIDENT s | UIDENT s | ESCAPED_IDENT s when
                                  is_keyword s -> pp f "%s__" s
                              | SYMBOL s -> pp f "( %s )" s
                              | LIDENT s | UIDENT s | ESCAPED_IDENT s ->
                                  pp_print_string f s
                              | tok ->
                                  failwith
                                    (sprintf
                                       "Bad token used as an identifier: %s"
                                       (Token.to_string tok))))
                method type_params =
                  fun f ->
                    function
                    | [] -> ()
                    | [ x ] -> pp f "%a@ " o#ctyp x
                    | l -> pp f "@[<1>(%a)@]@ " (list o#ctyp ",@ ") l
                method class_params =
                  fun f ->
                    function
                    | Ast.TyCom (_, t1, t2) ->
                        pp f "@[<1>%a,@ %a@]" o#class_params t1
                          o#class_params t2
                    | x -> o#ctyp f x
                method mutable_flag = fun f b -> o#flag f b "mutable"
                method rec_flag = fun f b -> o#flag f b "rec"
                method virtual_flag = fun f b -> o#flag f b "virtual"
                method private_flag = fun f b -> o#flag f b "private"
                method flag =
                  fun f b n ->
                    match b with
                    | Ast.BTrue -> (pp_print_string f n; pp f "@ ")
                    | Ast.BFalse -> ()
                    | Ast.BAnt s -> o#anti f s
                method anti = fun f s -> pp f "$%s$" s
                method seq =
                  fun f ->
                    function
                    | Ast.ExSem (_, e1, e2) ->
                        pp f "%a;@ %a" o#under_semi#seq e1 o#seq e2
                    | Ast.ExSeq (_, e) -> o#seq f e
                    | e -> o#expr f e
                method match_case =
                  fun f ->
                    function
                    | Ast.McNil _loc ->
                        pp f "@[<2>_@ ->@ %a@]" o#raise_match_failure _loc
                    | a -> o#match_case_aux f a
                method match_case_aux =
                  fun f ->
                    function
                    | Ast.McNil _ -> ()
                    | Ast.McAnt (_, s) -> o#anti f s
                    | Ast.McOr (_, a1, a2) ->
                        pp f "%a%a" o#match_case_aux a1 o#match_case_aux a2
                    | Ast.McArr (_, p, (Ast.ExNil _), e) ->
                        pp f "@ | @[<2>%a@ ->@ %a@]" o#patt p
                          o#under_pipe#expr e
                    | Ast.McArr (_, p, w, e) ->
                        pp f "@ | @[<2>%a@ when@ %a@ ->@ %a@]" o#patt p
                          o#under_pipe#expr w o#under_pipe#expr e
                method binding =
                  fun f bi ->
                    let () = o#node f bi Ast.loc_of_binding
                    in
                      match bi with
                      | Ast.BiNil _ -> ()
                      | Ast.BiAnd (_, b1, b2) ->
                          (o#binding f b1; pp f andsep; o#binding f b2)
                      | Ast.BiEq (_, p, e) ->
                          let (pl, e) =
                            (match p with
                             | Ast.PaTyc (_, _, _) -> ([], e)
                             | _ -> expr_fun_args e)
                          in
                            (match (p, e) with
                             | (Ast.PaId (_, (Ast.IdLid (_, _))),
                                Ast.ExTyc (_, e, t)) ->
                                 pp f "%a :@ %a =@ %a"
                                   (list o#simple_patt "@ ") (p :: pl) 
                                   o#ctyp t o#expr e
                             | _ ->
                                 pp f "%a @[<0>%a=@]@ %a" o#simple_patt p
                                   (list' o#simple_patt "" "@ ") pl o#expr e)
                      | Ast.BiSem (_, _, _) -> assert false
                      | Ast.BiAnt (_, s) -> o#anti f s
                method record_binding =
                  fun f bi ->
                    let () = o#node f bi Ast.loc_of_binding
                    in
                      match bi with
                      | Ast.BiNil _ -> ()
                      | Ast.BiEq (_, p, e) ->
                          pp f "@ @[<2>%a =@ %a@];" o#simple_patt p o#expr e
                      | Ast.BiSem (_, b1, b2) ->
                          (o#under_semi#record_binding f b1;
                           o#under_semi#record_binding f b2)
                      | Ast.BiAnd (_, _, _) -> assert false
                      | Ast.BiAnt (_, s) -> o#anti f s
                method object_dup =
                  fun f ->
                    list
                      (fun f (s, e) ->
                         pp f "@[<2>%a =@ %a@]" o#var s o#expr e)
                      ";@ " f
                method mk_patt_list =
                  function
                  | Ast.PaApp (_,
                      (Ast.PaApp (_, (Ast.PaId (_, (Ast.IdUid (_, "::")))),
                         p1)),
                      p2) ->
                      let (pl, c) = o#mk_patt_list p2 in ((p1 :: pl), c)
                  | Ast.PaId (_, (Ast.IdUid (_, "[]"))) -> ([], None)
                  | p -> ([], (Some p))
                method mk_expr_list =
                  function
                  | Ast.ExApp (_,
                      (Ast.ExApp (_, (Ast.ExId (_, (Ast.IdUid (_, "::")))),
                         e1)),
                      e2) ->
                      let (el, c) = o#mk_expr_list e2 in ((e1 :: el), c)
                  | Ast.ExId (_, (Ast.IdUid (_, "[]"))) -> ([], None)
                  | e -> ([], (Some e))
                method expr_list =
                  fun f ->
                    function
                    | [] -> pp f "[]"
                    | [ e ] -> pp f "[ %a ]" o#expr e
                    | el -> pp f "@[<2>[ %a@] ]" (list o#expr ";@ ") el
                method expr_list_cons =
                  fun simple f e ->
                    let (el, c) = o#mk_expr_list e
                    in
                      match c with
                      | None -> o#expr_list f el
                      | Some x ->
                          (if simple
                           then pp f "@[<2>(%a)@]"
                           else pp f "@[<2>%a@]") (list o#dot_expr " ::@ ")
                            (el @ [ x ])
                method patt_expr_fun_args =
                  fun f (p, e) ->
                    let (pl, e) = expr_fun_args e
                    in
                      pp f "%a@ ->@ %a" (list o#patt "@ ") (p :: pl) o#expr e
                method patt_class_expr_fun_args =
                  fun f (p, ce) ->
                    let (pl, ce) = class_expr_fun_args ce
                    in
                      pp f "%a =@]@ %a" (list o#patt "@ ") (p :: pl)
                        o#class_expr ce
                method constrain =
                  fun f (t1, t2) ->
                    pp f "@[<2>constraint@ %a =@ %a@]" o#ctyp t1 o#ctyp t2
                method sum_type =
                  fun f t -> (pp_print_string f "| "; o#ctyp f t)
                method string = fun f -> pp f "%s"
                method quoted_string = fun f -> pp f "%S"
                method intlike =
                  fun f s ->
                    if s.[0] = '-' then pp f "(%s)" s else pp f "%s" s
                method module_expr_get_functor_args =
                  fun accu ->
                    function
                    | Ast.MeFun (_, s, mt, me) ->
                        o#module_expr_get_functor_args ((s, mt) :: accu) me
                    | Ast.MeTyc (_, me, mt) ->
                        ((List.rev accu), me, (Some mt))
                    | me -> ((List.rev accu), me, None)
                method functor_args = fun f -> list o#functor_arg "@ " f
                method functor_arg =
                  fun f (s, mt) ->
                    pp f "@[<2>(%a :@ %a)@]" o#var s o#module_type mt
                method module_rec_binding =
                  fun f ->
                    function
                    | Ast.MbNil _ -> ()
                    | Ast.MbColEq (_, s, mt, me) ->
                        pp f "@[<2>%a :@ %a =@ %a@]" o#var s o#module_type mt
                          o#module_expr me
                    | Ast.MbCol (_, s, mt) ->
                        pp f "@[<2>%a :@ %a@]" o#var s o#module_type mt
                    | Ast.MbAnd (_, mb1, mb2) ->
                        (o#module_rec_binding f mb1;
                         pp f andsep;
                         o#module_rec_binding f mb2)
                    | Ast.MbAnt (_, s) -> o#anti f s
                method class_declaration =
                  fun f ->
                    function
                    | Ast.CeTyc (_, ce, ct) ->
                        pp f "%a :@ %a" o#class_expr ce o#class_type ct
                    | ce -> o#class_expr f ce
                method raise_match_failure =
                  fun f _loc ->
                    let n = Loc.file_name _loc in
                    let l = Loc.start_line _loc in
                    let c = (Loc.start_off _loc) - (Loc.start_bol _loc)
                    in
                      o#expr f
                        (Ast.ExApp (_loc,
                           Ast.ExId (_loc, Ast.IdLid (_loc, "raise")),
                           Ast.ExApp (_loc,
                             Ast.ExApp (_loc,
                               Ast.ExApp (_loc,
                                 Ast.ExId (_loc,
                                   Ast.IdUid (_loc, "Match_failure")),
                                 Ast.ExStr (_loc, Ast.safe_string_escaped n)),
                               Ast.ExInt (_loc, string_of_int l)),
                             Ast.ExInt (_loc, string_of_int c))))
                method node : 'a. formatter -> 'a -> ('a -> Loc.t) -> unit =
                  fun f node loc_of_node ->
                    o#print_comments_before (loc_of_node node) f
                method ident =
                  fun f i ->
                    let () = o#node f i Ast.loc_of_ident
                    in
                      match i with
                      | Ast.IdAcc (_, i1, i2) ->
                          pp f "%a.@,%a" o#ident i1 o#ident i2
                      | Ast.IdApp (_, i1, i2) ->
                          pp f "%a@,(%a)" o#ident i1 o#ident i2
                      | Ast.IdAnt (_, s) -> o#anti f s
                      | Ast.IdLid (_, s) | Ast.IdUid (_, s) -> o#var f s
                method private var_ident =
                  {<  var_conversion = true; >}#ident
                method expr =
                  fun f e ->
                    let () = o#node f e Ast.loc_of_expr
                    in
                      match e with
                      | (Ast.ExLet (_, _, _, _) | Ast.ExLmd (_, _, _, _) as
                         e) when semi -> pp f "(%a)" o#reset#expr e
                      | (Ast.ExMat (_, _, _) | Ast.ExTry (_, _, _) |
                           Ast.ExFun (_, _)
                         as e) when pipe || semi ->
                          pp f "(%a)" o#reset#expr e
                      | Ast.ExApp (_, (Ast.ExId (_, (Ast.IdLid (_, "~-")))),
                          x) -> pp f "@[<2>-@,%a@]" o#expr x
                      | Ast.ExApp (_, (Ast.ExId (_, (Ast.IdLid (_, "~-.")))),
                          x) -> pp f "@[<2>-.@,%a@]" o#expr x
                      | Ast.ExApp (_,
                          (Ast.ExApp (_,
                             (Ast.ExId (_, (Ast.IdUid (_, "::")))), _)),
                          _) -> o#expr_list_cons false f e
                      | Ast.ExApp (_loc,
                          (Ast.ExApp (_, (Ast.ExId (_, (Ast.IdLid (_, n)))),
                             x)),
                          y) when is_infix n ->
                          pp f "@[<2>%a@ %s@ %a@]" o#dot_expr x n o#dot_expr
                            y
                      | Ast.ExApp (_, x, y) ->
                          let (a, al) = get_expr_args x [ y ]
                          in
                            if
                              (not curry_constr) &&
                                (Ast.is_expr_constructor a)
                            then
                              (match al with
                               | [ Ast.ExTup (_, _) ] ->
                                   pp f "@[<2>%a@ (%a)@]" o#dot_expr x 
                                     o#expr y
                               | [ _ ] ->
                                   pp f "@[<2>%a@ %a@]" o#dot_expr x
                                     o#dot_expr y
                               | al ->
                                   pp f "@[<2>%a@ (%a)@]" o#dot_expr a
                                     (list o#under_pipe#expr ",@ ") al)
                            else
                              pp f "@[<2>%a@]" (list o#dot_expr "@ ")
                                (a :: al)
                      | Ast.ExAss (_,
                          (Ast.ExAcc (_, e1,
                             (Ast.ExId (_, (Ast.IdLid (_, "val")))))),
                          e2) -> pp f "@[<2>%a :=@ %a@]" o#expr e1 o#expr e2
                      | Ast.ExAss (_, e1, e2) ->
                          pp f "@[<2>%a@ <-@ %a@]" o#expr e1 o#expr e2
                      | Ast.ExFun (loc, (Ast.McNil _)) ->
                          pp f "@[<2>fun@ _@ ->@ %a@]" o#raise_match_failure
                            loc
                      | Ast.ExFun (_, (Ast.McArr (_, p, (Ast.ExNil _), e)))
                          when is_irrefut_patt p ->
                          pp f "@[<2>fun@ %a@]" o#patt_expr_fun_args (p, e)
                      | Ast.ExFun (_, a) ->
                          pp f "@[<hv0>function%a@]" o#match_case a
                      | Ast.ExIfe (_, e1, e2, e3) ->
                          pp f
                            "@[<hv0>@[<2>if@ %a@]@ @[<2>then@ %a@]@ @[<2>else@ %a@]@]"
                            o#expr e1 o#under_semi#expr e2 o#under_semi#expr
                            e3
                      | Ast.ExLaz (_, e) -> pp f "@[<2>lazy@ %a@]" o#expr e
                      | Ast.ExLet (_, r, bi, e) ->
                          (match e with
                           | Ast.ExLet (_, _, _, _) ->
                               pp f "@[<0>@[<2>let %a%a in@]@ %a@]"
                                 o#rec_flag r o#binding bi o#reset_semi#expr
                                 e
                           | _ ->
                               pp f
                                 "@[<hv0>@[<2>let %a%a@]@ @[<hv2>in@ %a@]@]"
                                 o#rec_flag r o#binding bi o#reset_semi#expr
                                 e)
                      | Ast.ExMat (_, e, a) ->
                          pp f "@[<hv0>@[<hv0>@[<2>match %a@]@ with@]%a@]"
                            o#expr e o#match_case a
                      | Ast.ExTry (_, e, a) ->
                          pp f "@[<0>@[<hv2>try@ %a@]@ @[<0>with%a@]@]"
                            o#expr e o#match_case a
                      | Ast.ExAsf _ -> pp f "@[<2>assert@ false@]"
                      | Ast.ExAsr (_, e) -> pp f "@[<2>assert@ %a@]" o#expr e
                      | Ast.ExLmd (_, s, me, e) ->
                          pp f "@[<2>let module %a =@ %a@]@ @[<2>in@ %a@]"
                            o#var s o#module_expr me o#expr e
                      | e -> o#dot_expr f e
                method dot_expr =
                  fun f e ->
                    let () = o#node f e Ast.loc_of_expr
                    in
                      match e with
                      | Ast.ExAcc (_, e,
                          (Ast.ExId (_, (Ast.IdLid (_, "val"))))) ->
                          pp f "@[<2>!@,%a@]" o#simple_expr e
                      | Ast.ExAcc (_, e1, e2) ->
                          pp f "@[<2>%a.@,%a@]" o#dot_expr e1 o#dot_expr e2
                      | Ast.ExAre (_, e1, e2) ->
                          pp f "@[<2>%a.@,(%a)@]" o#dot_expr e1 o#expr e2
                      | Ast.ExSte (_, e1, e2) ->
                          pp f "%a.@[<1>[@,%a@]@,]" o#dot_expr e1 o#expr e2
                      | Ast.ExSnd (_, e, s) ->
                          pp f "@[<2>%a#@,%s@]" o#dot_expr e s
                      | e -> o#simple_expr f e
                method simple_expr =
                  fun f e ->
                    let () = o#node f e Ast.loc_of_expr
                    in
                      match e with
                      | Ast.ExNil _ -> ()
                      | Ast.ExSeq (_, e) -> pp f "@[<hv1>(%a)@]" o#seq e
                      | Ast.ExApp (_,
                          (Ast.ExApp (_,
                             (Ast.ExId (_, (Ast.IdUid (_, "::")))), _)),
                          _) -> o#expr_list_cons true f e
                      | Ast.ExTup (_, e) -> pp f "@[<1>(%a)@]" o#expr e
                      | Ast.ExArr (_, e) ->
                          pp f "@[<0>@[<2>[|@ %a@]@ |]@]" o#under_semi#expr e
                      | Ast.ExCoe (_, e, (Ast.TyNil _), t) ->
                          pp f "@[<2>(%a :>@ %a)@]" o#expr e o#ctyp t
                      | Ast.ExCoe (_, e, t1, t2) ->
                          pp f "@[<2>(%a :@ %a :>@ %a)@]" o#expr e o#ctyp t1
                            o#ctyp t2
                      | Ast.ExTyc (_, e, t) ->
                          pp f "@[<2>(%a :@ %a)@]" o#expr e o#ctyp t
                      | Ast.ExAnt (_, s) -> o#anti f s
                      | Ast.ExFor (_, s, e1, e2, df, e3) ->
                          pp f
                            "@[<hv0>@[<hv2>@[<2>for %a =@ %a@ %a@ %a@ do@]@ %a@]@ done@]"
                            o#var s o#expr e1 o#direction_flag df o#expr e2
                            o#seq e3
                      | Ast.ExInt (_, s) -> pp f "%a" o#intlike s
                      | Ast.ExNativeInt (_, s) -> pp f "%an" o#intlike s
                      | Ast.ExInt64 (_, s) -> pp f "%aL" o#intlike s
                      | Ast.ExInt32 (_, s) -> pp f "%al" o#intlike s
                      | Ast.ExFlo (_, s) -> pp f "%s" s
                      | Ast.ExChr (_, s) -> pp f "'%s'" (ocaml_char s)
                      | Ast.ExId (_, i) -> o#var_ident f i
                      | Ast.ExRec (_, b, (Ast.ExNil _)) ->
                          pp f "@[<hv0>@[<hv2>{@ %a@]@ }@]" o#record_binding
                            b
                      | Ast.ExRec (_, b, e) ->
                          pp f "@[<hv0>@[<hv2>{@ (%a)@ with@ %a@]@ }@]"
                            o#expr e o#record_binding b
                      | Ast.ExStr (_, s) -> pp f "\"%s\"" s
                      | Ast.ExWhi (_, e1, e2) ->
                          pp f "@[<2>while@ %a@ do@ %a@ done@]" o#expr e1
                            o#seq e2
                      | Ast.ExLab (_, s, (Ast.ExNil _)) -> pp f "~%s" s
                      | Ast.ExLab (_, s, e) ->
                          pp f "@[<2>~%s:@ %a@]" s o#dot_expr e
                      | Ast.ExOlb (_, s, (Ast.ExNil _)) -> pp f "?%s" s
                      | Ast.ExOlb (_, s, e) ->
                          pp f "@[<2>?%s:@ %a@]" s o#dot_expr e
                      | Ast.ExVrn (_, s) -> pp f "`%a" o#var s
                      | Ast.ExOvr (_, b) ->
                          pp f "@[<hv0>@[<hv2>{<@ %a@]@ >}@]"
                            o#record_binding b
                      | Ast.ExObj (_, (Ast.PaNil _), cst) ->
                          pp f "@[<hv0>@[<hv2>object@ %a@]@ end@]"
                            o#class_str_item cst
                      | Ast.ExObj (_, (Ast.PaTyc (_, p, t)), cst) ->
                          pp f
                            "@[<hv0>@[<hv2>object @[<1>(%a :@ %a)@]@ %a@]@ end@]"
                            o#patt p o#ctyp t o#class_str_item cst
                      | Ast.ExObj (_, p, cst) ->
                          pp f
                            "@[<hv0>@[<hv2>object @[<2>(%a)@]@ %a@]@ end@]"
                            o#patt p o#class_str_item cst
                      | Ast.ExNew (_, i) -> pp f "@[<2>new@ %a@]" o#ident i
                      | Ast.ExCom (_, e1, e2) ->
                          pp f "%a,@ %a" o#simple_expr e1 o#simple_expr e2
                      | Ast.ExSem (_, e1, e2) ->
                          pp f "%a;@ %a" o#under_semi#expr e1 o#expr e2
                      | Ast.ExApp (_, _, _) | Ast.ExAcc (_, _, _) |
                          Ast.ExAre (_, _, _) | Ast.ExSte (_, _, _) |
                          Ast.ExAss (_, _, _) | Ast.ExSnd (_, _, _) |
                          Ast.ExFun (_, _) | Ast.ExMat (_, _, _) |
                          Ast.ExTry (_, _, _) | Ast.ExIfe (_, _, _, _) |
                          Ast.ExLet (_, _, _, _) | Ast.ExLmd (_, _, _, _) |
                          Ast.ExAsr (_, _) | Ast.ExAsf _ | Ast.ExLaz (_, _)
                          -> pp f "(%a)" o#reset#expr e
                method direction_flag =
                  fun f b ->
                    match b with
                    | Ast.BTrue -> pp_print_string f "to"
                    | Ast.BFalse -> pp_print_string f "downto"
                    | Ast.BAnt s -> o#anti f s
                method patt =
                  fun f p ->
                    let () = o#node f p Ast.loc_of_patt
                    in
                      match p with
                      | Ast.PaAli (_, p1, p2) ->
                          pp f "@[<1>(%a@ as@ %a)@]" o#patt p1 o#patt p2
                      | Ast.PaEq (_, p1, p2) ->
                          pp f "@[<2>%a =@ %a@]" o#patt p1 o#patt p2
                      | Ast.PaSem (_, p1, p2) ->
                          pp f "%a;@ %a" o#patt p1 o#patt p2
                      | p -> o#patt1 f p
                method patt1 =
                  fun f ->
                    function
                    | Ast.PaOrp (_, p1, p2) ->
                        pp f "@[<2>%a@ |@ %a@]" o#patt1 p1 o#patt2 p2
                    | p -> o#patt2 f p
                method patt2 = fun f p -> o#patt3 f p
                method patt3 =
                  fun f ->
                    function
                    | Ast.PaRng (_, p1, p2) ->
                        pp f "@[<2>%a@ ..@ %a@]" o#patt3 p1 o#patt4 p2
                    | Ast.PaCom (_, p1, p2) ->
                        pp f "%a,@ %a" o#patt3 p1 o#patt3 p2
                    | p -> o#patt4 f p
                method patt4 =
                  fun f ->
                    function
                    | (Ast.PaApp (_,
                         (Ast.PaApp (_,
                            (Ast.PaId (_, (Ast.IdUid (_, "::")))), _)),
                         _)
                       as p) ->
                        let (pl, c) = o#mk_patt_list p
                        in
                          (match c with
                           | None ->
                               pp f "@[<2>[@ %a@]@ ]" (list o#patt ";@ ") pl
                           | Some x ->
                               pp f "@[<2>%a@]" (list o#patt5 " ::@ ")
                                 (pl @ [ x ]))
                    | p -> o#patt5 f p
                method patt5 =
                  fun f ->
                    function
                    | (Ast.PaApp (_,
                         (Ast.PaApp (_,
                            (Ast.PaId (_, (Ast.IdUid (_, "::")))), _)),
                         _)
                       as p) -> o#simple_patt f p
                    | Ast.PaApp (_, x, y) ->
                        let (a, al) = get_patt_args x [ y ]
                        in
                          if
                            (not curry_constr) && (Ast.is_patt_constructor a)
                          then
                            (match al with
                             | [ Ast.PaTup (_, _) ] ->
                                 pp f "@[<2>%a@ (%a)@]" o#simple_patt x
                                   o#patt y
                             | [ _ ] ->
                                 pp f "@[<2>%a@ %a@]" o#patt5 x o#simple_patt
                                   y
                             | al ->
                                 pp f "@[<2>%a@ (%a)@]" o#patt5 a
                                   (list o#simple_patt ",@ ") al)
                          else
                            pp f "@[<2>%a@]" (list o#simple_patt "@ ")
                              (a :: al)
                    | p -> o#simple_patt f p
                method simple_patt =
                  fun f p ->
                    let () = o#node f p Ast.loc_of_patt
                    in
                      match p with
                      | Ast.PaNil _ -> ()
                      | Ast.PaId (_, i) -> o#var_ident f i
                      | Ast.PaAnt (_, s) -> o#anti f s
                      | Ast.PaAny _ -> pp f "_"
                      | Ast.PaTup (_, p) -> pp f "@[<1>(%a)@]" o#patt3 p
                      | Ast.PaRec (_, p) -> pp f "@[<hv2>{@ %a@]@ }" o#patt p
                      | Ast.PaStr (_, s) -> pp f "\"%s\"" s
                      | Ast.PaTyc (_, p, t) ->
                          pp f "@[<1>(%a :@ %a)@]" o#patt p o#ctyp t
                      | Ast.PaNativeInt (_, s) -> pp f "%an" o#intlike s
                      | Ast.PaInt64 (_, s) -> pp f "%aL" o#intlike s
                      | Ast.PaInt32 (_, s) -> pp f "%al" o#intlike s
                      | Ast.PaInt (_, s) -> pp f "%a" o#intlike s
                      | Ast.PaFlo (_, s) -> pp f "%s" s
                      | Ast.PaChr (_, s) -> pp f "'%s'" (ocaml_char s)
                      | Ast.PaLab (_, s, (Ast.PaNil _)) -> pp f "~%s" s
                      | Ast.PaVrn (_, s) -> pp f "`%a" o#var s
                      | Ast.PaTyp (_, i) -> pp f "@[<2>#%a@]" o#ident i
                      | Ast.PaArr (_, p) -> pp f "@[<2>[|@ %a@]@ |]" o#patt p
                      | Ast.PaLab (_, s, p) ->
                          pp f "@[<2>~%s:@ (%a)@]" s o#patt p
                      | Ast.PaOlb (_, s, (Ast.PaNil _)) -> pp f "?%s" s
                      | Ast.PaOlb (_, "", p) -> pp f "@[<2>?(%a)@]" o#patt p
                      | Ast.PaOlb (_, s, p) ->
                          pp f "@[<2>?%s:@,@[<1>(%a)@]@]" s o#patt p
                      | Ast.PaOlbi (_, "", p, e) ->
                          pp f "@[<2>?(%a =@ %a)@]" o#patt p o#expr e
                      | Ast.PaOlbi (_, s, p, e) ->
                          pp f "@[<2>?%s:@,@[<1>(%a =@ %a)@]@]" s o#patt p
                            o#expr e
                      | (Ast.PaApp (_, _, _) | Ast.PaAli (_, _, _) |
                           Ast.PaOrp (_, _, _) | Ast.PaRng (_, _, _) |
                           Ast.PaCom (_, _, _) | Ast.PaSem (_, _, _) |
                           Ast.PaEq (_, _, _)
                         as p) -> pp f "@[<1>(%a)@]" o#patt p
                method simple_ctyp =
                  fun f t ->
                    let () = o#node f t Ast.loc_of_ctyp
                    in
                      match t with
                      | Ast.TyId (_, i) -> o#ident f i
                      | Ast.TyAnt (_, s) -> o#anti f s
                      | Ast.TyAny _ -> pp f "_"
                      | Ast.TyLab (_, s, t) ->
                          pp f "@[<2>%s:@ %a@]" s o#simple_ctyp t
                      | Ast.TyOlb (_, s, t) ->
                          pp f "@[<2>?%s:@ %a@]" s o#simple_ctyp t
                      | Ast.TyObj (_, (Ast.TyNil _), Ast.BFalse) ->
                          pp f "< >"
                      | Ast.TyObj (_, (Ast.TyNil _), Ast.BTrue) ->
                          pp f "< .. >"
                      | Ast.TyObj (_, t, Ast.BTrue) ->
                          pp f "@[<0>@[<2><@ %a@ ..@]@ >@]" o#ctyp t
                      | Ast.TyObj (_, t, Ast.BFalse) ->
                          pp f "@[<0>@[<2><@ %a@]@ >@]" o#ctyp t
                      | Ast.TyQuo (_, s) -> pp f "'%a" o#var s
                      | Ast.TyRec (_, t) -> pp f "@[<2>{@ %a@]@ }" o#ctyp t
                      | Ast.TySum (_, t) -> pp f "@[<0>%a@]" o#sum_type t
                      | Ast.TyTup (_, t) -> pp f "@[<1>(%a)@]" o#ctyp t
                      | Ast.TyVrnEq (_, t) -> pp f "@[<2>[@ %a@]@ ]" o#ctyp t
                      | Ast.TyVrnInf (_, t) ->
                          pp f "@[<2>[<@ %a@]@,]" o#ctyp t
                      | Ast.TyVrnInfSup (_, t1, t2) ->
                          pp f "@[<2>[<@ %a@ >@ %a@]@ ]" o#ctyp t1 o#ctyp t2
                      | Ast.TyVrnSup (_, t) ->
                          pp f "@[<2>[>@ %a@]@,]" o#ctyp t
                      | Ast.TyCls (_, i) -> pp f "@[<2>#%a@]" o#ident i
                      | Ast.TyMan (_, t1, t2) ->
                          pp f "@[<2>%a =@ %a@]" o#simple_ctyp t1
                            o#simple_ctyp t2
                      | Ast.TyVrn (_, s) -> pp f "`%a" o#var s
                      | Ast.TySta (_, t1, t2) ->
                          pp f "%a *@ %a" o#simple_ctyp t1 o#simple_ctyp t2
                      | t -> pp f "@[<1>(%a)@]" o#ctyp t
                method ctyp =
                  fun f t ->
                    let () = o#node f t Ast.loc_of_ctyp
                    in
                      match t with
                      | Ast.TyAli (_, t1, t2) ->
                          pp f "@[<2>%a@ as@ %a@]" o#simple_ctyp t1
                            o#simple_ctyp t2
                      | Ast.TyArr (_, t1, t2) ->
                          pp f "@[<2>%a@ ->@ %a@]" o#ctyp1 t1 o#ctyp t2
                      | Ast.TyQuP (_, s) -> pp f "+'%a" o#var s
                      | Ast.TyQuM (_, s) -> pp f "-'%a" o#var s
                      | Ast.TyOr (_, t1, t2) ->
                          pp f "%a@ | %a" o#ctyp t1 o#ctyp t2
                      | Ast.TyCol (_, t1, (Ast.TyMut (_, t2))) ->
                          pp f "@[mutable@ %a :@ %a@]" o#ctyp t1 o#ctyp t2
                      | Ast.TyCol (_, t1, t2) ->
                          pp f "@[<2>%a :@ %a@]" o#ctyp t1 o#ctyp t2
                      | Ast.TySem (_, t1, t2) ->
                          pp f "%a;@ %a" o#ctyp t1 o#ctyp t2
                      | Ast.TyOf (_, t, (Ast.TyNil _)) -> o#ctyp f t
                      | Ast.TyOf (_, t1, t2) ->
                          pp f "@[<h>%a@ @[<3>of@ %a@]@]" o#ctyp t1
                            o#constructor_type t2
                      | Ast.TyOfAmp (_, t1, t2) ->
                          pp f "@[<h>%a@ @[<3>of &@ %a@]@]" o#ctyp t1
                            o#constructor_type t2
                      | Ast.TyAnd (_, t1, t2) ->
                          pp f "%a@ and %a" o#ctyp t1 o#ctyp t2
                      | Ast.TyMut (_, t) ->
                          pp f "@[<2>mutable@ %a@]" o#ctyp t
                      | Ast.TyAmp (_, t1, t2) ->
                          pp f "%a@ &@ %a" o#ctyp t1 o#ctyp t2
                      | Ast.TyDcl (_, tn, tp, te, cl) ->
                          (pp f "@[<2>%a%a@]" o#type_params tp o#var tn;
                           (match te with
                            | Ast.TyQuo (_, s) when
                                not
                                  (List.exists
                                     (function
                                      | Ast.TyQuo (_, s') -> s = s'
                                      | _ -> false)
                                     tp)
                                -> ()
                            | _ -> pp f " =@ %a" o#ctyp te);
                           if cl <> []
                           then pp f "@ %a" (list o#constrain "@ ") cl
                           else ())
                      | t -> o#ctyp1 f t
                method ctyp1 =
                  fun f ->
                    function
                    | Ast.TyApp (_, t1, t2) ->
                        (match get_ctyp_args t1 [ t2 ] with
                         | (_, [ _ ]) ->
                             pp f "@[<2>%a@ %a@]" o#simple_ctyp t2
                               o#simple_ctyp t1
                         | (a, al) ->
                             pp f "@[<2>(%a)@ %a@]" (list o#ctyp ",@ ") al
                               o#simple_ctyp a)
                    | Ast.TyPol (_, t1, t2) ->
                        let (a, al) = get_ctyp_args t1 []
                        in
                          pp f "@[<2>%a.@ %a@]" (list o#ctyp "@ ") (a :: al)
                            o#ctyp t2
                    | Ast.TyPrv (_, t) ->
                        pp f "@[private@ %a@]" o#simple_ctyp t
                    | t -> o#simple_ctyp f t
                method constructor_type =
                  fun f t ->
                    match t with
                    | Ast.TyAnd (loc, t1, t2) ->
                        let () = o#node f t (fun _ -> loc)
                        in
                          pp f "%a@ * %a" o#constructor_type t1
                            o#constructor_type t2
                    | Ast.TyArr (_, _, _) -> pp f "(%a)" o#ctyp t
                    | t -> o#ctyp f t
                method sig_item =
                  fun f sg ->
                    let () = o#node f sg Ast.loc_of_sig_item
                    in
                      match sg with
                      | Ast.SgNil _ -> ()
                      | Ast.SgSem (_, sg, (Ast.SgNil _)) |
                          Ast.SgSem (_, (Ast.SgNil _), sg) -> o#sig_item f sg
                      | Ast.SgSem (_, sg1, sg2) ->
                          (o#sig_item f sg1; cut f; o#sig_item f sg2)
                      | Ast.SgExc (_, t) ->
                          pp f "@[<2>exception@ %a%s@]" o#ctyp t semisep
                      | Ast.SgExt (_, s1, t, s2) ->
                          pp f "@[<2>external@ %a :@ %a =@ %a%s@]" o#var s1
                            o#ctyp t o#quoted_string s2 semisep
                      | Ast.SgMod (_, s1, (Ast.MtFun (_, s2, mt1, mt2))) ->
                          let rec loop accu =
                            (function
                             | Ast.MtFun (_, s, mt1, mt2) ->
                                 loop ((s, mt1) :: accu) mt2
                             | mt -> ((List.rev accu), mt)) in
                          let (al, mt) = loop [ (s2, mt1) ] mt2
                          in
                            pp f "@[<2>module %a@ @[<0>%a@] :@ %a%s@]" 
                              o#var s1 o#functor_args al o#module_type mt
                              semisep
                      | Ast.SgMod (_, s, mt) ->
                          pp f "@[<2>module %a :@ %a%s@]" o#var s
                            o#module_type mt semisep
                      | Ast.SgMty (_, s, mt) ->
                          pp f "@[<2>module type %a =@ %a%s@]" o#var s
                            o#module_type mt semisep
                      | Ast.SgOpn (_, sl) ->
                          pp f "@[<2>open@ %a%s@]" o#ident sl semisep
                      | Ast.SgTyp (_, t) ->
                          pp f "@[<hv0>@[<hv2>type %a@]%s@]" o#ctyp t semisep
                      | Ast.SgVal (_, s, t) ->
                          pp f "@[<2>%s %a :@ %a%s@]" value_val o#var s
                            o#ctyp t semisep
                      | Ast.SgInc (_, mt) ->
                          pp f "@[<2>include@ %a%s@]" o#module_type mt
                            semisep
                      | Ast.SgClt (_, ct) ->
                          pp f "@[<2>class type %a%s@]" o#class_type ct
                            semisep
                      | Ast.SgCls (_, ce) ->
                          pp f "@[<2>class %a%s@]" o#class_type ce semisep
                      | Ast.SgRecMod (_, mb) ->
                          pp f "@[<2>module rec %a%s@]" o#module_rec_binding
                            mb semisep
                      | Ast.SgDir (_, _, _) -> ()
                      | Ast.SgAnt (_, s) -> pp f "%a%s" o#anti s semisep
                method str_item =
                  fun f st ->
                    let () = o#node f st Ast.loc_of_str_item
                    in
                      match st with
                      | Ast.StNil _ -> ()
                      | Ast.StSem (_, st, (Ast.StNil _)) |
                          Ast.StSem (_, (Ast.StNil _), st) -> o#str_item f st
                      | Ast.StSem (_, st1, st2) ->
                          (o#str_item f st1; cut f; o#str_item f st2)
                      | Ast.StExc (_, t, Ast.ONone) ->
                          pp f "@[<2>exception@ %a%s@]" o#ctyp t semisep
                      | Ast.StExc (_, t, (Ast.OSome sl)) ->
                          pp f "@[<2>exception@ %a =@ %a%s@]" o#ctyp t
                            o#ident sl semisep
                      | Ast.StExt (_, s1, t, s2) ->
                          pp f "@[<2>external@ %a :@ %a =@ %a%s@]" o#var s1
                            o#ctyp t o#quoted_string s2 semisep
                      | Ast.StMod (_, s1, (Ast.MeFun (_, s2, mt1, me))) ->
                          (match o#module_expr_get_functor_args [ (s2, mt1) ]
                                   me
                           with
                           | (al, me, Some mt2) ->
                               pp f
                                 "@[<2>module %a@ @[<0>%a@] :@ %a =@ %a%s@]"
                                 o#var s1 o#functor_args al o#module_type mt2
                                 o#module_expr me semisep
                           | (al, me, _) ->
                               pp f "@[<2>module %a@ @[<0>%a@] =@ %a%s@]"
                                 o#var s1 o#functor_args al o#module_expr me
                                 semisep)
                      | Ast.StMod (_, s, (Ast.MeTyc (_, me, mt))) ->
                          pp f "@[<2>module %a :@ %a =@ %a%s@]" o#var s
                            o#module_type mt o#module_expr me semisep
                      | Ast.StMod (_, s, me) ->
                          pp f "@[<2>module %a =@ %a%s@]" o#var s
                            o#module_expr me semisep
                      | Ast.StMty (_, s, mt) ->
                          pp f "@[<2>module type %a =@ %a%s@]" o#var s
                            o#module_type mt semisep
                      | Ast.StOpn (_, sl) ->
                          pp f "@[<2>open@ %a%s@]" o#ident sl semisep
                      | Ast.StTyp (_, t) ->
                          pp f "@[<hv0>@[<hv2>type %a@]%s@]" o#ctyp t semisep
                      | Ast.StVal (_, r, bi) ->
                          pp f "@[<2>%s %a%a%s@]" value_let o#rec_flag r
                            o#binding bi semisep
                      | Ast.StExp (_, e) ->
                          pp f "@[<2>let _ =@ %a%s@]" o#expr e semisep
                      | Ast.StInc (_, me) ->
                          pp f "@[<2>include@ %a%s@]" o#module_expr me
                            semisep
                      | Ast.StClt (_, ct) ->
                          pp f "@[<2>class type %a%s@]" o#class_type ct
                            semisep
                      | Ast.StCls (_, ce) ->
                          pp f "@[<hv2>class %a%s@]" o#class_declaration ce
                            semisep
                      | Ast.StRecMod (_, mb) ->
                          pp f "@[<2>module rec %a%s@]" o#module_rec_binding
                            mb semisep
                      | Ast.StDir (_, _, _) -> ()
                      | Ast.StAnt (_, s) -> pp f "%a%s" o#anti s semisep
                      | Ast.StExc (_, _, (Ast.OAnt _)) -> assert false
                method module_type =
                  fun f mt ->
                    let () = o#node f mt Ast.loc_of_module_type
                    in
                      match mt with
                      | Ast.MtId (_, i) -> o#ident f i
                      | Ast.MtAnt (_, s) -> o#anti f s
                      | Ast.MtFun (_, s, mt1, mt2) ->
                          pp f "@[<2>functor@ @[<1>(%a :@ %a)@]@ ->@ %a@]"
                            o#var s o#module_type mt1 o#module_type mt2
                      | Ast.MtQuo (_, s) -> pp f "'%a" o#var s
                      | Ast.MtSig (_, sg) ->
                          pp f "@[<hv0>@[<hv2>sig@ %a@]@ end@]" o#sig_item sg
                      | Ast.MtWit (_, mt, wc) ->
                          pp f "@[<2>%a@ with@ %a@]" o#module_type mt
                            o#with_constraint wc
                method with_constraint =
                  fun f wc ->
                    let () = o#node f wc Ast.loc_of_with_constr
                    in
                      match wc with
                      | Ast.WcNil _ -> ()
                      | Ast.WcTyp (_, t1, t2) ->
                          pp f "@[<2>type@ %a =@ %a@]" o#ctyp t1 o#ctyp t2
                      | Ast.WcMod (_, i1, i2) ->
                          pp f "@[<2>module@ %a =@ %a@]" o#ident i1 o#ident
                            i2
                      | Ast.WcAnd (_, wc1, wc2) ->
                          (o#with_constraint f wc1;
                           pp f andsep;
                           o#with_constraint f wc2)
                      | Ast.WcAnt (_, s) -> o#anti f s
                method module_expr =
                  fun f me ->
                    let () = o#node f me Ast.loc_of_module_expr
                    in
                      match me with
                      | Ast.MeId (_, i) -> o#ident f i
                      | Ast.MeAnt (_, s) -> o#anti f s
                      | Ast.MeApp (_, me1, me2) ->
                          pp f "@[<2>%a@,(%a)@]" o#module_expr me1
                            o#module_expr me2
                      | Ast.MeFun (_, s, mt, me) ->
                          pp f "@[<2>functor@ @[<1>(%a :@ %a)@]@ ->@ %a@]"
                            o#var s o#module_type mt o#module_expr me
                      | Ast.MeStr (_, st) ->
                          pp f "@[<hv0>@[<hv2>struct@ %a@]@ end@]" o#str_item
                            st
                      | Ast.MeTyc (_, (Ast.MeStr (_, st)),
                          (Ast.MtSig (_, sg))) ->
                          pp f
                            "@[<2>@[<hv2>struct@ %a@]@ end :@ @[<hv2>sig@ %a@]@ end@]"
                            o#str_item st o#sig_item sg
                      | Ast.MeTyc (_, me, mt) ->
                          pp f "@[<1>(%a :@ %a)@]" o#module_expr me
                            o#module_type mt
                method class_expr =
                  fun f ce ->
                    let () = o#node f ce Ast.loc_of_class_expr
                    in
                      match ce with
                      | Ast.CeApp (_, ce, e) ->
                          pp f "@[<2>%a@ %a@]" o#class_expr ce o#expr e
                      | Ast.CeCon (_, Ast.BFalse, i, (Ast.TyNil _)) ->
                          pp f "@[<2>%a@]" o#ident i
                      | Ast.CeCon (_, Ast.BFalse, i, t) ->
                          pp f "@[<2>@[<1>[%a]@]@ %a@]" o#class_params t
                            o#ident i
                      | Ast.CeCon (_, Ast.BTrue, i, (Ast.TyNil _)) ->
                          pp f "@[<2>virtual@ %a@]" o#ident i
                      | Ast.CeCon (_, Ast.BTrue, i, t) ->
                          pp f "@[<2>virtual@ @[<1>[%a]@]@ %a@]"
                            o#class_params t o#ident i
                      | Ast.CeFun (_, p, ce) ->
                          pp f "@[<2>fun@ %a@ ->@ %a@]" o#patt p o#class_expr
                            ce
                      | Ast.CeLet (_, r, bi, ce) ->
                          pp f "@[<2>let %a%a@]@ @[<2>in@ %a@]" o#rec_flag r
                            o#binding bi o#class_expr ce
                      | Ast.CeStr (_, (Ast.PaNil _), cst) ->
                          pp f "@[<hv0>@[<hv2>object %a@]@ end@]"
                            o#class_str_item cst
                      | Ast.CeStr (_, p, cst) ->
                          pp f
                            "@[<hv0>@[<hv2>object @[<1>(%a)@]@ %a@]@ end@]"
                            o#patt p o#class_str_item cst
                      | Ast.CeTyc (_, ce, ct) ->
                          pp f "@[<1>(%a :@ %a)@]" o#class_expr ce
                            o#class_type ct
                      | Ast.CeAnt (_, s) -> o#anti f s
                      | Ast.CeAnd (_, ce1, ce2) ->
                          (o#class_expr f ce1;
                           pp f andsep;
                           o#class_expr f ce2)
                      | Ast.CeEq (_, ce1, (Ast.CeFun (_, p, ce2))) when
                          is_irrefut_patt p ->
                          pp f "@[<2>%a@ %a" o#class_expr ce1
                            o#patt_class_expr_fun_args (p, ce2)
                      | Ast.CeEq (_, ce1, ce2) ->
                          pp f "@[<2>%a =@]@ %a" o#class_expr ce1
                            o#class_expr ce2
                      | _ -> assert false
                method class_type =
                  fun f ct ->
                    let () = o#node f ct Ast.loc_of_class_type
                    in
                      match ct with
                      | Ast.CtCon (_, Ast.BFalse, i, (Ast.TyNil _)) ->
                          pp f "@[<2>%a@]" o#ident i
                      | Ast.CtCon (_, Ast.BFalse, i, t) ->
                          pp f "@[<2>[@,%a@]@,]@ %a" o#class_params t 
                            o#ident i
                      | Ast.CtCon (_, Ast.BTrue, i, (Ast.TyNil _)) ->
                          pp f "@[<2>virtual@ %a@]" o#ident i
                      | Ast.CtCon (_, Ast.BTrue, i, t) ->
                          pp f "@[<2>virtual@ [@,%a@]@,]@ %a" o#class_params
                            t o#ident i
                      | Ast.CtFun (_, t, ct) ->
                          pp f "@[<2>%a@ ->@ %a@]" o#simple_ctyp t
                            o#class_type ct
                      | Ast.CtSig (_, (Ast.TyNil _), csg) ->
                          pp f "@[<hv0>@[<hv2>object@ %a@]@ end@]"
                            o#class_sig_item csg
                      | Ast.CtSig (_, t, csg) ->
                          pp f
                            "@[<hv0>@[<hv2>object @[<1>(%a)@]@ %a@]@ end@]"
                            o#ctyp t o#class_sig_item csg
                      | Ast.CtAnt (_, s) -> o#anti f s
                      | Ast.CtAnd (_, ct1, ct2) ->
                          (o#class_type f ct1;
                           pp f andsep;
                           o#class_type f ct2)
                      | Ast.CtCol (_, ct1, ct2) ->
                          pp f "%a :@ %a" o#class_type ct1 o#class_type ct2
                      | Ast.CtEq (_, ct1, ct2) ->
                          pp f "%a =@ %a" o#class_type ct1 o#class_type ct2
                      | _ -> assert false
                method class_sig_item =
                  fun f csg ->
                    let () = o#node f csg Ast.loc_of_class_sig_item
                    in
                      match csg with
                      | Ast.CgNil _ -> ()
                      | Ast.CgSem (_, csg, (Ast.CgNil _)) |
                          Ast.CgSem (_, (Ast.CgNil _), csg) ->
                          o#class_sig_item f csg
                      | Ast.CgSem (_, csg1, csg2) ->
                          (o#class_sig_item f csg1;
                           cut f;
                           o#class_sig_item f csg2)
                      | Ast.CgCtr (_, t1, t2) ->
                          pp f "@[<2>type@ %a =@ %a%s@]" o#ctyp t1 o#ctyp t2
                            semisep
                      | Ast.CgInh (_, ct) ->
                          pp f "@[<2>inherit@ %a%s@]" o#class_type ct semisep
                      | Ast.CgMth (_, s, pr, t) ->
                          pp f "@[<2>method %a%a :@ %a%s@]" o#private_flag pr
                            o#var s o#ctyp t semisep
                      | Ast.CgVir (_, s, pr, t) ->
                          pp f "@[<2>method virtual %a%a :@ %a%s@]"
                            o#private_flag pr o#var s o#ctyp t semisep
                      | Ast.CgVal (_, s, mu, vi, t) ->
                          pp f "@[<2>%s %a%a%a :@ %a%s@]" value_val
                            o#mutable_flag mu o#virtual_flag vi o#var s
                            o#ctyp t semisep
                      | Ast.CgAnt (_, s) -> pp f "%a%s" o#anti s semisep
                method class_str_item =
                  fun f cst ->
                    let () = o#node f cst Ast.loc_of_class_str_item
                    in
                      match cst with
                      | Ast.CrNil _ -> ()
                      | Ast.CrSem (_, cst, (Ast.CrNil _)) |
                          Ast.CrSem (_, (Ast.CrNil _), cst) ->
                          o#class_str_item f cst
                      | Ast.CrSem (_, cst1, cst2) ->
                          (o#class_str_item f cst1;
                           cut f;
                           o#class_str_item f cst2)
                      | Ast.CrCtr (_, t1, t2) ->
                          pp f "@[<2>type %a =@ %a%s@]" o#ctyp t1 o#ctyp t2
                            semisep
                      | Ast.CrInh (_, ce, "") ->
                          pp f "@[<2>inherit@ %a%s@]" o#class_expr ce semisep
                      | Ast.CrInh (_, ce, s) ->
                          pp f "@[<2>inherit@ %a as@ %a%s@]" o#class_expr ce
                            o#var s semisep
                      | Ast.CrIni (_, e) ->
                          pp f "@[<2>initializer@ %a%s@]" o#expr e semisep
                      | Ast.CrMth (_, s, pr, e, (Ast.TyNil _)) ->
                          pp f "@[<2>method %a%a =@ %a%s@]" o#private_flag pr
                            o#var s o#expr e semisep
                      | Ast.CrMth (_, s, pr, e, t) ->
                          pp f "@[<2>method %a%a :@ %a =@ %a%s@]"
                            o#private_flag pr o#var s o#ctyp t o#expr e
                            semisep
                      | Ast.CrVir (_, s, pr, t) ->
                          pp f "@[<2>method virtual@ %a%a :@ %a%s@]"
                            o#private_flag pr o#var s o#ctyp t semisep
                      | Ast.CrVvr (_, s, mu, t) ->
                          pp f "@[<2>%s virtual %a%a :@ %a%s@]" value_val
                            o#mutable_flag mu o#var s o#ctyp t semisep
                      | Ast.CrVal (_, s, mu, e) ->
                          pp f "@[<2>%s %a%a =@ %a%s@]" value_val
                            o#mutable_flag mu o#var s o#expr e semisep
                      | Ast.CrAnt (_, s) -> pp f "%a%s" o#anti s semisep
                method implem =
                  fun f st ->
                    match st with
                    | Ast.StExp (_, e) ->
                        pp f "@[<0>%a%s@]@." o#expr e semisep
                    | st -> pp f "@[<v0>%a@]@." o#str_item st
                method interf = fun f sg -> pp f "@[<v0>%a@]@." o#sig_item sg
              end
            let with_outfile output_file fct arg =
              let call close f =
                ((try fct f arg with | exn -> (close (); raise exn));
                 close ())
              in
                match output_file with
                | None -> call (fun () -> ()) std_formatter
                | Some s ->
                    let oc = open_out s in
                    let f = formatter_of_out_channel oc
                    in call (fun () -> close_out oc) f
            let print output_file fct =
              let o = new printer () in with_outfile output_file (fct o)
            let print_interf ?input_file:(_) ?output_file sg =
              print output_file (fun o -> o#interf) sg
            let print_implem ?input_file:(_) ?output_file st =
              print output_file (fun o -> o#implem) st
          end
        module MakeMore (Syntax : Sig.Camlp4Syntax) :
          Sig.Printer with module Ast = Syntax.Ast =
          struct
            include Make(Syntax)
            let semisep = ref false
            let margin = ref 78
            let comments = ref true
            let locations = ref false
            let curry_constr = ref false
            let print output_file fct =
              let o =
                new printer ~comments: !comments ~curry_constr: !curry_constr
                  () in
              let o =
                if !semisep then o#set_semisep ";;" else o#set_semisep "" in
              let o = if !locations then o#set_loc_and_comments else o
              in
                with_outfile output_file
                  (fun f ->
                     let () = Format.pp_set_margin f !margin
                     in Format.fprintf f "@[<v0>%a@]@." (fct o))
            let print_interf ?input_file:(_) ?output_file sg =
              print output_file (fun o -> o#interf) sg
            let print_implem ?input_file:(_) ?output_file st =
              print output_file (fun o -> o#implem) st
            let _ =
              Options.add "-l" (Arg.Int (fun i -> margin := i))
                "<length> line length for pretty printing."
            let _ =
              Options.add "-ss" (Arg.Set semisep) "Print double semicolons."
            let _ =
              Options.add "-curry-constr" (Arg.Set curry_constr)
                "Use currified constructors."
            let _ =
              Options.add "-no_ss" (Arg.Clear semisep)
                "Do not print double semicolons (default)."
            let _ =
              Options.add "-no_comments" (Arg.Clear comments)
                "Do not add comments."
            let _ =
              Options.add "-add_locations" (Arg.Set locations)
                "Add locations as comment."
          end
      end
    module OCamlr :
      sig
        module Id : Sig.Id
        module Make (Syntax : Sig.Camlp4Syntax) :
          sig
            open Format
            include Sig.Camlp4Syntax with module Loc = Syntax.Loc
              and module Warning = Syntax.Warning
              and module Token = Syntax.Token and module Ast = Syntax.Ast
              and module Gram = Syntax.Gram
            class printer :
              ?curry_constr: bool ->
                ?comments: bool ->
                  unit -> object ('a) inherit OCaml.Make(Syntax).printer end
            val with_outfile :
              string option -> (formatter -> 'a -> unit) -> 'a -> unit
            val print :
              string option ->
                (printer -> formatter -> 'a -> unit) -> 'a -> unit
            val print_interf :
              ?input_file: string ->
                ?output_file: string -> Ast.sig_item -> unit
            val print_implem :
              ?input_file: string ->
                ?output_file: string -> Ast.str_item -> unit
          end
        module MakeMore (Syntax : Sig.Camlp4Syntax) :
          Sig.Printer with module Ast = Syntax.Ast
      end =
      struct
        open Format
        module Id =
          struct
            let name = "Camlp4.Printers.OCamlr"
            let version =
              "$Id: OCamlr.ml,v 1.16 2006/10/10 22:32:43 ertai Exp $"
          end
        module Make (Syntax : Sig.Camlp4Syntax) =
          struct
            include Syntax
            open Sig
            module PP_o = OCaml.Make(Syntax)
            open PP_o
            let pp = fprintf
            class printer ?curry_constr:(init_curry_constr = true)
                    ?(comments = true) () =
              object (o)
                inherit
                  PP_o.printer ~curry_constr: init_curry_constr ~comments () as
                  super
                val semisep = ";"
                val andsep =
                  ("@]@ @[<2>and@ " : (unit, formatter, unit) format)
                val value_val = "value"
                val value_let = "value"
                val mode = if comments then `comments else `no_comments
                val curry_constr = init_curry_constr
                val first_match_case = true
                method under_pipe = o
                method under_semi = o
                method reset_semi = o
                method reset = o
                method private unset_first_match_case =
                  {<  first_match_case = false; >}
                method private set_first_match_case =
                  {<  first_match_case = true; >}
                method seq =
                  fun f e ->
                    let rec self right f e =
                      let go_right = self right
                      and go_left = self false
                      in
                        match e with
                        | Ast.ExLet (_, r, bi, e1) ->
                            if right
                            then
                              pp f "@[<2>let %a%a@];@ %a" o#rec_flag r
                                o#binding bi go_right e1
                            else pp f "(%a)" o#expr e
                        | Ast.ExSeq (_, e) -> go_right f e
                        | Ast.ExSem (_, e1, e2) ->
                            (pp f "%a;@ " go_left e1;
                             (match (right, e2) with
                              | (true, Ast.ExLet (_, r, bi, e3)) ->
                                  pp f "@[<2>let %a%a@];@ %a" o#rec_flag r
                                    o#binding bi go_right e3
                              | _ -> go_right f e2))
                        | e -> o#expr f e
                    in self true f e
                method var =
                  fun f ->
                    function
                    | "" -> pp f "$lid:\"\"$"
                    | "[]" -> pp f "[]"
                    | "()" -> pp f "()"
                    | " True" -> pp f "True"
                    | " False" -> pp f "False"
                    | v ->
                        (match lex_string v with
                         | LIDENT s | UIDENT s | ESCAPED_IDENT s when
                             is_keyword s -> pp f "\\%s" s
                         | SYMBOL s -> pp f "\\%s" s
                         | LIDENT s | UIDENT s | ESCAPED_IDENT s ->
                             pp_print_string f s
                         | tok ->
                             failwith
                               (sprintf "Bad token used as an identifier: %s"
                                  (Token.to_string tok)))
                method type_params =
                  fun f ->
                    function
                    | [] -> ()
                    | [ x ] -> pp f "@ %a" o#ctyp x
                    | l -> pp f "@ @[<1>%a@]" (list o#ctyp "@ ") l
                method match_case =
                  fun f ->
                    function
                    | Ast.McNil _ -> pp f "@ []"
                    | m ->
                        pp f "@ [ %a ]" o#set_first_match_case#match_case_aux
                          m
                method match_case_aux =
                  fun f ->
                    function
                    | Ast.McNil _ -> ()
                    | Ast.McAnt (_, s) -> o#anti f s
                    | Ast.McOr (_, a1, a2) ->
                        pp f "%a%a" o#match_case_aux a1
                          o#unset_first_match_case#match_case_aux a2
                    | Ast.McArr (_, p, (Ast.ExNil _), e) ->
                        let () = if first_match_case then () else pp f "@ | "
                        in
                          pp f "@[<2>%a@ ->@ %a@]" o#patt p o#under_pipe#expr
                            e
                    | Ast.McArr (_, p, w, e) ->
                        let () = if first_match_case then () else pp f "@ | "
                        in
                          pp f "@[<2>%a@ when@ %a@ ->@ %a@]" o#patt p
                            o#under_pipe#expr w o#under_pipe#expr e
                method sum_type = fun f t -> pp f "@[<hv0>[ %a ]@]" o#ctyp t
                method ident =
                  fun f i ->
                    let () = o#node f i Ast.loc_of_ident
                    in
                      match i with
                      | Ast.IdApp (_, i1, i2) ->
                          pp f "%a@ %a" o#dot_ident i1 o#dot_ident i2
                      | i -> o#dot_ident f i
                method private dot_ident =
                  fun f i ->
                    let () = o#node f i Ast.loc_of_ident
                    in
                      match i with
                      | Ast.IdAcc (_, i1, i2) ->
                          pp f "%a.@,%a" o#dot_ident i1 o#dot_ident i2
                      | Ast.IdAnt (_, s) -> o#anti f s
                      | Ast.IdLid (_, s) | Ast.IdUid (_, s) -> o#var f s
                      | i -> pp f "(%a)" o#ident i
                method patt4 =
                  fun f ->
                    function
                    | (Ast.PaApp (_,
                         (Ast.PaApp (_,
                            (Ast.PaId (_, (Ast.IdUid (_, "::")))), _)),
                         _)
                       as p) ->
                        let (pl, c) = o#mk_patt_list p
                        in
                          (match c with
                           | None ->
                               pp f "@[<2>[@ %a@]@ ]" (list o#patt ";@ ") pl
                           | Some x ->
                               pp f "@[<2>[ %a ::@ %a ]@]"
                                 (list o#patt ";@ ") pl o#patt x)
                    | p -> super#patt4 f p
                method expr_list_cons =
                  fun _ f e ->
                    let (el, c) = o#mk_expr_list e
                    in
                      match c with
                      | None -> o#expr_list f el
                      | Some x ->
                          pp f "@[<2>[ %a ::@ %a ]@]" (list o#expr ";@ ") el
                            o#expr x
                method expr =
                  fun f e ->
                    let () = o#node f e Ast.loc_of_expr
                    in
                      match e with
                      | Ast.ExAss (_, e1, e2) ->
                          pp f "@[<2>%a@ :=@ %a@]" o#expr e1 o#expr e2
                      | Ast.ExFun (_, (Ast.McArr (_, p, (Ast.ExNil _), e)))
                          when Ast.is_irrefut_patt p ->
                          pp f "@[<2>fun@ %a@]" o#patt_expr_fun_args (p, e)
                      | Ast.ExFun (_, a) ->
                          pp f "@[<hv0>fun%a@]" o#match_case a
                      | Ast.ExAsf _ -> pp f "@[<2>assert@ False@]"
                      | e -> super#expr f e
                method dot_expr =
                  fun f e ->
                    let () = o#node f e Ast.loc_of_expr
                    in
                      match e with
                      | Ast.ExAcc (_, e,
                          (Ast.ExId (_, (Ast.IdLid (_, "val"))))) ->
                          pp f "@[<2>%a.@,val@]" o#simple_expr e
                      | e -> super#dot_expr f e
                method simple_expr =
                  fun f e ->
                    let () = o#node f e Ast.loc_of_expr
                    in
                      match e with
                      | Ast.ExFor (_, s, e1, e2, Ast.BTrue, e3) ->
                          pp f
                            "@[<hv0>@[<hv2>@[<2>for %a@ =@ %a@ to@ %a@ do {@]@ %a@]@ }@]"
                            o#var s o#expr e1 o#expr e2 o#seq e3
                      | Ast.ExFor (_, s, e1, e2, Ast.BFalse, e3) ->
                          pp f
                            "@[<hv0>@[<hv2>@[<2>for %a@ =@ %a@ downto@ %a@ do {@]@ %a@]@ }@]"
                            o#var s o#expr e1 o#expr e2 o#seq e3
                      | Ast.ExWhi (_, e1, e2) ->
                          pp f "@[<2>while@ %a@ do {@ %a@ }@]" o#expr e1
                            o#seq e2
                      | Ast.ExSeq (_, e) ->
                          pp f "@[<hv0>@[<hv2>do {@ %a@]@ }@]" o#seq e
                      | e -> super#simple_expr f e
                method ctyp =
                  fun f t ->
                    let () = o#node f t Ast.loc_of_ctyp
                    in
                      match t with
                      | Ast.TyDcl (_, tn, tp, te, cl) ->
                          (pp f "@[<2>%a%a@]" o#var tn o#type_params tp;
                           (match te with
                            | Ast.TyQuo (_, s) when
                                not
                                  (List.exists
                                     (function
                                      | Ast.TyQuo (_, s') -> s = s'
                                      | _ -> false)
                                     tp)
                                -> ()
                            | _ -> pp f " =@ %a" o#ctyp te);
                           if cl <> []
                           then pp f "@ %a" (list o#constrain "@ ") cl
                           else ())
                      | Ast.TyCol (_, t1, (Ast.TyMut (_, t2))) ->
                          pp f "@[%a :@ mutable %a@]" o#ctyp t1 o#ctyp t2
                      | t -> super#ctyp f t
                method simple_ctyp =
                  fun f t ->
                    let () = o#node f t Ast.loc_of_ctyp
                    in
                      match t with
                      | Ast.TyVrnEq (_, t) ->
                          pp f "@[<2>[ =@ %a@]@ ]" o#ctyp t
                      | Ast.TyVrnInf (_, t) ->
                          pp f "@[<2>[ <@ %a@]@,]" o#ctyp t
                      | Ast.TyVrnInfSup (_, t1, t2) ->
                          pp f "@[<2>[ <@ %a@ >@ %a@]@ ]" o#ctyp t1 o#ctyp t2
                      | Ast.TyVrnSup (_, t) ->
                          pp f "@[<2>[ >@ %a@]@,]" o#ctyp t
                      | Ast.TyMan (_, t1, t2) ->
                          pp f "@[<2>%a@ ==@ %a@]" o#simple_ctyp t1
                            o#simple_ctyp t2
                      | Ast.TyLab (_, s, t) ->
                          pp f "@[<2>~%s:@ %a@]" s o#simple_ctyp t
                      | t -> super#simple_ctyp f t
                method ctyp1 =
                  fun f ->
                    function
                    | Ast.TyApp (_, t1, t2) ->
                        (match get_ctyp_args t1 [ t2 ] with
                         | (_, [ _ ]) ->
                             pp f "@[<2>%a@ %a@]" o#simple_ctyp t1
                               o#simple_ctyp t2
                         | (a, al) ->
                             pp f "@[<2>%a@]" (list o#simple_ctyp "@ ")
                               (a :: al))
                    | Ast.TyPol (_, t1, t2) ->
                        let (a, al) = get_ctyp_args t1 []
                        in
                          pp f "@[<2>! %a.@ %a@]" (list o#ctyp "@ ")
                            (a :: al) o#ctyp t2
                    | t -> super#ctyp1 f t
                method constructor_type =
                  fun f t ->
                    match t with
                    | Ast.TyAnd (loc, t1, t2) ->
                        let () = o#node f t (fun _ -> loc)
                        in
                          pp f "%a@ and %a" o#constructor_type t1
                            o#constructor_type t2
                    | t -> o#ctyp f t
                method str_item =
                  fun f st ->
                    match st with
                    | Ast.StExp (_, e) -> pp f "@[<2>%a%s@]" o#expr e semisep
                    | st -> super#str_item f st
                method module_expr =
                  fun f me ->
                    let () = o#node f me Ast.loc_of_module_expr
                    in
                      match me with
                      | Ast.MeApp (_, me1, me2) ->
                          pp f "@[<2>%a@,(%a)@]" o#module_expr me1
                            o#module_expr me2
                      | me -> super#module_expr f me
                method implem = fun f st -> pp f "@[<v0>%a@]@." o#str_item st
                method class_type =
                  fun f ct ->
                    let () = o#node f ct Ast.loc_of_class_type
                    in
                      match ct with
                      | Ast.CtFun (_, t, ct) ->
                          pp f "@[<2>[ %a ] ->@ %a@]" o#simple_ctyp t
                            o#class_type ct
                      | Ast.CtCon (_, Ast.BFalse, i, (Ast.TyNil _)) ->
                          pp f "@[<2>%a@]" o#ident i
                      | Ast.CtCon (_, Ast.BFalse, i, t) ->
                          pp f "@[<2>%a [@,%a@]@,]" o#ident i o#class_params
                            t
                      | Ast.CtCon (_, Ast.BTrue, i, (Ast.TyNil _)) ->
                          pp f "@[<2>virtual@ %a@]" o#ident i
                      | Ast.CtCon (_, Ast.BTrue, i, t) ->
                          pp f "@[<2>virtual@ %a@ [@,%a@]@,]" o#ident i
                            o#class_params t
                      | ct -> super#class_type f ct
                method class_expr =
                  fun f ce ->
                    let () = o#node f ce Ast.loc_of_class_expr
                    in
                      match ce with
                      | Ast.CeCon (_, Ast.BFalse, i, (Ast.TyNil _)) ->
                          pp f "@[<2>%a@]" o#ident i
                      | Ast.CeCon (_, Ast.BFalse, i, t) ->
                          pp f "@[<2>%a@ @[<1>[%a]@]@]" o#ident i
                            o#class_params t
                      | Ast.CeCon (_, Ast.BTrue, i, (Ast.TyNil _)) ->
                          pp f "@[<2>virtual@ %a@]" o#ident i
                      | Ast.CeCon (_, Ast.BTrue, i, t) ->
                          pp f "@[<2>virtual@ %a@ @[<1>[%a]@]@]" o#ident i
                            o#ctyp t
                      | ce -> super#class_expr f ce
              end
            let with_outfile = with_outfile
            let print = print
            let print_interf = print_interf
            let print_implem = print_implem
          end
        module MakeMore (Syntax : Sig.Camlp4Syntax) :
          Sig.Printer with module Ast = Syntax.Ast =
          struct
            include Make(Syntax)
            let margin = ref 78
            let comments = ref true
            let locations = ref false
            let curry_constr = ref true
            let print output_file fct =
              let o =
                new printer ~comments: !comments ~curry_constr: !curry_constr
                  () in
              let o = if !locations then o#set_loc_and_comments else o
              in
                with_outfile output_file
                  (fun f ->
                     let () = Format.pp_set_margin f !margin
                     in Format.fprintf f "@[<v0>%a@]@." (fct o))
            let print_interf ?input_file:(_) ?output_file sg =
              print output_file (fun o -> o#interf) sg
            let print_implem ?input_file:(_) ?output_file st =
              print output_file (fun o -> o#implem) st
            let _ =
              Options.add "-l" (Arg.Int (fun i -> margin := i))
                "<length> line length for pretty printing."
            let _ =
              Options.add "-no_comments" (Arg.Clear comments)
                "Do not add comments."
            let _ =
              Options.add "-add_locations" (Arg.Set locations)
                "Add locations as comment."
          end
      end
  end
module OCamlInitSyntax =
  struct
    module Make
      (Warning : Sig.Warning)
      (Ast : Sig.Camlp4Ast with module Loc = Warning.Loc)
      (Gram :
        Sig.Grammar.Static with module Loc = Warning.Loc with
          type Token.t = Sig.camlp4_token)
      (Quotation : Sig.Quotation with module Ast = Sig.Camlp4AstToAst(Ast)) :
      Sig.Camlp4Syntax with module Loc = Ast.Loc and module Ast = Ast
      and module Token = Gram.Token and module Gram = Gram
      and module AntiquotSyntax.Ast = Sig.Camlp4AstToAst(Ast)
      and module Quotation = Quotation =
      struct
        module Warning = Warning
        module Loc = Ast.Loc
        module Ast = Ast
        module Gram = Gram
        module Token = Gram.Token
        open Sig
        let a_CHAR = Gram.Entry.mk "a_CHAR"
        let a_FLOAT = Gram.Entry.mk "a_FLOAT"
        let a_INT = Gram.Entry.mk "a_INT"
        let a_INT32 = Gram.Entry.mk "a_INT32"
        let a_INT64 = Gram.Entry.mk "a_INT64"
        let a_LABEL = Gram.Entry.mk "a_LABEL"
        let a_LIDENT = Gram.Entry.mk "a_LIDENT"
        let a_LIDENT_or_operator = Gram.Entry.mk "a_LIDENT_or_operator"
        let a_NATIVEINT = Gram.Entry.mk "a_NATIVEINT"
        let a_OPTLABEL = Gram.Entry.mk "a_OPTLABEL"
        let a_STRING = Gram.Entry.mk "a_STRING"
        let a_UIDENT = Gram.Entry.mk "a_UIDENT"
        let a_ident = Gram.Entry.mk "a_ident"
        let amp_ctyp = Gram.Entry.mk "amp_ctyp"
        let and_ctyp = Gram.Entry.mk "and_ctyp"
        let match_case = Gram.Entry.mk "match_case"
        let match_case0 = Gram.Entry.mk "match_case0"
        let binding = Gram.Entry.mk "binding"
        let class_declaration = Gram.Entry.mk "class_declaration"
        let class_description = Gram.Entry.mk "class_description"
        let class_expr = Gram.Entry.mk "class_expr"
        let class_fun_binding = Gram.Entry.mk "class_fun_binding"
        let class_fun_def = Gram.Entry.mk "class_fun_def"
        let class_info_for_class_expr =
          Gram.Entry.mk "class_info_for_class_expr"
        let class_info_for_class_type =
          Gram.Entry.mk "class_info_for_class_type"
        let class_longident = Gram.Entry.mk "class_longident"
        let class_longident_and_param =
          Gram.Entry.mk "class_longident_and_param"
        let class_name_and_param = Gram.Entry.mk "class_name_and_param"
        let class_sig_item = Gram.Entry.mk "class_sig_item"
        let class_signature = Gram.Entry.mk "class_signature"
        let class_str_item = Gram.Entry.mk "class_str_item"
        let class_structure = Gram.Entry.mk "class_structure"
        let class_type = Gram.Entry.mk "class_type"
        let class_type_declaration = Gram.Entry.mk "class_type_declaration"
        let class_type_longident = Gram.Entry.mk "class_type_longident"
        let class_type_longident_and_param =
          Gram.Entry.mk "class_type_longident_and_param"
        let class_type_plus = Gram.Entry.mk "class_type_plus"
        let comma_ctyp = Gram.Entry.mk "comma_ctyp"
        let comma_expr = Gram.Entry.mk "comma_expr"
        let comma_ipatt = Gram.Entry.mk "comma_ipatt"
        let comma_patt = Gram.Entry.mk "comma_patt"
        let comma_type_parameter = Gram.Entry.mk "comma_type_parameter"
        let constrain = Gram.Entry.mk "constrain"
        let constructor_arg_list = Gram.Entry.mk "constructor_arg_list"
        let constructor_declaration = Gram.Entry.mk "constructor_declaration"
        let constructor_declarations =
          Gram.Entry.mk "constructor_declarations"
        let ctyp = Gram.Entry.mk "ctyp"
        let cvalue_binding = Gram.Entry.mk "cvalue_binding"
        let direction_flag = Gram.Entry.mk "direction_flag"
        let dummy = Gram.Entry.mk "dummy"
        let entry_eoi = Gram.Entry.mk "entry_eoi"
        let eq_expr = Gram.Entry.mk "eq_expr"
        let expr = Gram.Entry.mk "expr"
        let expr_eoi = Gram.Entry.mk "expr_eoi"
        let field = Gram.Entry.mk "field"
        let field_expr = Gram.Entry.mk "field_expr"
        let fun_binding = Gram.Entry.mk "fun_binding"
        let fun_def = Gram.Entry.mk "fun_def"
        let ident = Gram.Entry.mk "ident"
        let implem = Gram.Entry.mk "implem"
        let interf = Gram.Entry.mk "interf"
        let ipatt = Gram.Entry.mk "ipatt"
        let ipatt_tcon = Gram.Entry.mk "ipatt_tcon"
        let label = Gram.Entry.mk "label"
        let label_declaration = Gram.Entry.mk "label_declaration"
        let label_expr = Gram.Entry.mk "label_expr"
        let label_ipatt = Gram.Entry.mk "label_ipatt"
        let label_longident = Gram.Entry.mk "label_longident"
        let label_patt = Gram.Entry.mk "label_patt"
        let labeled_ipatt = Gram.Entry.mk "labeled_ipatt"
        let let_binding = Gram.Entry.mk "let_binding"
        let meth_list = Gram.Entry.mk "meth_list"
        let module_binding = Gram.Entry.mk "module_binding"
        let module_binding0 = Gram.Entry.mk "module_binding0"
        let module_declaration = Gram.Entry.mk "module_declaration"
        let module_expr = Gram.Entry.mk "module_expr"
        let module_longident = Gram.Entry.mk "module_longident"
        let module_longident_with_app =
          Gram.Entry.mk "module_longident_with_app"
        let module_rec_declaration = Gram.Entry.mk "module_rec_declaration"
        let module_type = Gram.Entry.mk "module_type"
        let more_ctyp = Gram.Entry.mk "more_ctyp"
        let name_tags = Gram.Entry.mk "name_tags"
        let opt_as_lident = Gram.Entry.mk "opt_as_lident"
        let opt_class_self_patt = Gram.Entry.mk "opt_class_self_patt"
        let opt_class_self_type = Gram.Entry.mk "opt_class_self_type"
        let opt_class_signature = Gram.Entry.mk "opt_class_signature"
        let opt_class_structure = Gram.Entry.mk "opt_class_structure"
        let opt_comma_ctyp = Gram.Entry.mk "opt_comma_ctyp"
        let opt_dot_dot = Gram.Entry.mk "opt_dot_dot"
        let opt_eq_ctyp = Gram.Entry.mk "opt_eq_ctyp"
        let opt_expr = Gram.Entry.mk "opt_expr"
        let opt_meth_list = Gram.Entry.mk "opt_meth_list"
        let opt_mutable = Gram.Entry.mk "opt_mutable"
        let opt_polyt = Gram.Entry.mk "opt_polyt"
        let opt_private = Gram.Entry.mk "opt_private"
        let opt_rec = Gram.Entry.mk "opt_rec"
        let opt_sig_items = Gram.Entry.mk "opt_sig_items"
        let opt_str_items = Gram.Entry.mk "opt_str_items"
        let opt_virtual = Gram.Entry.mk "opt_virtual"
        let opt_when_expr = Gram.Entry.mk "opt_when_expr"
        let patt = Gram.Entry.mk "patt"
        let patt_as_patt_opt = Gram.Entry.mk "patt_as_patt_opt"
        let patt_eoi = Gram.Entry.mk "patt_eoi"
        let patt_tcon = Gram.Entry.mk "patt_tcon"
        let phrase = Gram.Entry.mk "phrase"
        let pipe_ctyp = Gram.Entry.mk "pipe_ctyp"
        let poly_type = Gram.Entry.mk "poly_type"
        let row_field = Gram.Entry.mk "row_field"
        let sem_ctyp = Gram.Entry.mk "sem_ctyp"
        let sem_expr = Gram.Entry.mk "sem_expr"
        let sem_expr_for_list = Gram.Entry.mk "sem_expr_for_list"
        let sem_patt = Gram.Entry.mk "sem_patt"
        let sem_patt_for_list = Gram.Entry.mk "sem_patt_for_list"
        let semi = Gram.Entry.mk "semi"
        let sequence = Gram.Entry.mk "sequence"
        let sig_item = Gram.Entry.mk "sig_item"
        let sig_items = Gram.Entry.mk "sig_items"
        let star_ctyp = Gram.Entry.mk "star_ctyp"
        let str_item = Gram.Entry.mk "str_item"
        let str_items = Gram.Entry.mk "str_items"
        let top_phrase = Gram.Entry.mk "top_phrase"
        let type_constraint = Gram.Entry.mk "type_constraint"
        let type_declaration = Gram.Entry.mk "type_declaration"
        let type_ident_and_parameters =
          Gram.Entry.mk "type_ident_and_parameters"
        let type_kind = Gram.Entry.mk "type_kind"
        let type_longident = Gram.Entry.mk "type_longident"
        let type_longident_and_parameters =
          Gram.Entry.mk "type_longident_and_parameters"
        let type_parameter = Gram.Entry.mk "type_parameter"
        let type_parameters = Gram.Entry.mk "type_parameters"
        let typevars = Gram.Entry.mk "typevars"
        let use_file = Gram.Entry.mk "use_file"
        let val_longident = Gram.Entry.mk "val_longident"
        let value_let = Gram.Entry.mk "value_let"
        let value_val = Gram.Entry.mk "value_val"
        let with_constr = Gram.Entry.mk "with_constr"
        let expr_quot = Gram.Entry.mk "quotation of expression"
        let patt_quot = Gram.Entry.mk "quotation of pattern"
        let ctyp_quot = Gram.Entry.mk "quotation of type"
        let str_item_quot = Gram.Entry.mk "quotation of structure item"
        let sig_item_quot = Gram.Entry.mk "quotation of signature item"
        let class_str_item_quot =
          Gram.Entry.mk "quotation of class structure item"
        let class_sig_item_quot =
          Gram.Entry.mk "quotation of class signature item"
        let module_expr_quot = Gram.Entry.mk "quotation of module expression"
        let module_type_quot = Gram.Entry.mk "quotation of module type"
        let class_type_quot = Gram.Entry.mk "quotation of class type"
        let class_expr_quot = Gram.Entry.mk "quotation of class expression"
        let with_constr_quot = Gram.Entry.mk "quotation of with constraint"
        let binding_quot = Gram.Entry.mk "quotation of binding"
        let match_case_quot =
          Gram.Entry.mk "quotation of match_case (try/match/function case)"
        let module_binding_quot =
          Gram.Entry.mk "quotation of module rec binding"
        let ident_quot = Gram.Entry.mk "quotation of identifier"
        let _ =
          Gram.extend (top_phrase : 'top_phrase Gram.Entry.t)
            ((fun () ->
                (None,
                 [ (None, None,
                    [ ([ Gram.Stoken
                           (((function | EOI -> true | _ -> false), "EOI")) ],
                       (Gram.Action.mk
                          (fun (__camlp4_0 : Gram.Token.t) (_loc : Loc.t) ->
                             match __camlp4_0 with
                             | EOI -> (None : 'top_phrase)
                             | _ -> assert false))) ]) ]))
               ())
        module AntiquotSyntax =
          struct
            module Loc = Ast.Loc
            module Ast = Sig.Camlp4AstToAst(Ast)
            module Gram = Gram
            let antiquot_expr = Gram.Entry.mk "antiquot_expr"
            let antiquot_patt = Gram.Entry.mk "antiquot_patt"
            let _ =
              (Gram.extend (antiquot_expr : 'antiquot_expr Gram.Entry.t)
                 ((fun () ->
                     (None,
                      [ (None, None,
                         [ ([ Gram.Snterm
                                (Gram.Entry.obj (expr : 'expr Gram.Entry.t));
                              Gram.Stoken
                                (((function | EOI -> true | _ -> false),
                                  "EOI")) ],
                            (Gram.Action.mk
                               (fun (__camlp4_0 : Gram.Token.t) (x : 'expr)
                                  (_loc : Loc.t) ->
                                  match __camlp4_0 with
                                  | EOI -> (x : 'antiquot_expr)
                                  | _ -> assert false))) ]) ]))
                    ());
               Gram.extend (antiquot_patt : 'antiquot_patt Gram.Entry.t)
                 ((fun () ->
                     (None,
                      [ (None, None,
                         [ ([ Gram.Snterm
                                (Gram.Entry.obj (patt : 'patt Gram.Entry.t));
                              Gram.Stoken
                                (((function | EOI -> true | _ -> false),
                                  "EOI")) ],
                            (Gram.Action.mk
                               (fun (__camlp4_0 : Gram.Token.t) (x : 'patt)
                                  (_loc : Loc.t) ->
                                  match __camlp4_0 with
                                  | EOI -> (x : 'antiquot_patt)
                                  | _ -> assert false))) ]) ]))
                    ()))
            let parse_expr loc str = Gram.parse_string antiquot_expr loc str
            let parse_patt loc str = Gram.parse_string antiquot_patt loc str
          end
        module Quotation = Quotation
        module Parser =
          struct
            module Ast = Ast
            let wrap directive_handler pa init_loc cs =
              let rec loop loc =
                let (pl, stopped_at_directive) = pa loc cs
                in
                  match stopped_at_directive with
                  | Some new_loc ->
                      let pl =
                        (match List.rev pl with
                         | [] -> assert false
                         | x :: xs ->
                             (match directive_handler x with
                              | None -> xs
                              | Some x -> x :: xs))
                      in (List.rev pl) @ (loop new_loc)
                  | None -> pl
              in loop init_loc
            let parse_implem ?(directive_handler = fun _ -> None) _loc cs =
              let l = wrap directive_handler (Gram.parse implem) _loc cs
              in Ast.stSem_of_list l
            let parse_interf ?(directive_handler = fun _ -> None) _loc cs =
              let l = wrap directive_handler (Gram.parse interf) _loc cs
              in Ast.sgSem_of_list l
          end
        module Printer = Struct.EmptyPrinter.Make(Ast)
      end
  end
module PreCast :
  sig
    type camlp4_token =
      Sig.camlp4_token =
        | KEYWORD of string | SYMBOL of string | LIDENT of string
        | UIDENT of string | ESCAPED_IDENT of string | INT of int * string
        | INT32 of int32 * string | INT64 of int64 * string
        | NATIVEINT of nativeint * string | FLOAT of float * string
        | CHAR of char * string | STRING of string * string | LABEL of string
        | OPTLABEL of string | QUOTATION of Sig.quotation
        | ANTIQUOT of string * string | COMMENT of string | BLANKS of string
        | NEWLINE | LINE_DIRECTIVE of int * string option | EOI
    module Id : Sig.Id
    module Loc : Sig.Loc
    module Warning : Sig.Warning with module Loc = Loc
    module Ast : Sig.Camlp4Ast with module Loc = Loc
    module Token : Sig.Token with module Loc = Loc and type t = camlp4_token
    module Lexer : Sig.Lexer with module Loc = Loc and module Token = Token
    module Gram : Sig.Grammar.Static with module Loc = Loc
      and module Token = Token
    module Quotation :
      Sig.Quotation with module Ast = Sig.Camlp4AstToAst(Ast)
    module DynLoader : Sig.DynLoader
    module AstFilters : Sig.AstFilters with module Ast = Ast
    module Syntax : Sig.Camlp4Syntax with module Loc = Loc
      and module Warning = Warning and module Token = Token
      and module Ast = Ast and module Gram = Gram
      and module Quotation = Quotation
    module Printers :
      sig
        module OCaml : Sig.Printer with module Ast = Sig.Camlp4AstToAst(Ast)
        module OCamlr : Sig.Printer with module Ast = Sig.Camlp4AstToAst(Ast)
        module DumpOCamlAst :
          Sig.Printer with module Ast = Sig.Camlp4AstToAst(Ast)
        module DumpCamlp4Ast :
          Sig.Printer with module Ast = Sig.Camlp4AstToAst(Ast)
        module Null : Sig.Printer with module Ast = Sig.Camlp4AstToAst(Ast)
      end
    module MakeGram (Lexer : Sig.Lexer with module Loc = Loc) :
      Sig.Grammar.Static with module Loc = Loc and module Token = Lexer.Token
  end =
  struct
    module Id =
      struct
        let name = "Camlp4.PreCast"
        let version = "$Id: PreCast.ml,v 1.3 2006/10/02 12:59:00 ertai Exp $"
      end
    type camlp4_token =
      Sig.camlp4_token =
        | KEYWORD of string | SYMBOL of string | LIDENT of string
        | UIDENT of string | ESCAPED_IDENT of string | INT of int * string
        | INT32 of int32 * string | INT64 of int64 * string
        | NATIVEINT of nativeint * string | FLOAT of float * string
        | CHAR of char * string | STRING of string * string | LABEL of string
        | OPTLABEL of string | QUOTATION of Sig.quotation
        | ANTIQUOT of string * string | COMMENT of string | BLANKS of string
        | NEWLINE | LINE_DIRECTIVE of int * string option | EOI
    module Loc = Struct.Loc
    module Warning = Struct.Warning.Make(Loc)
    module Ast = Struct.Camlp4Ast.Make(Loc)
    module Token = Struct.Token.Make(Loc)
    module Lexer = Struct.Lexer.Make(Token)
    module Gram = Struct.Grammar.Static.Make(Lexer)
    module DynLoader = Struct.DynLoader
    module Quotation = Struct.Quotation.Make(Ast)
    module Syntax = OCamlInitSyntax.Make(Warning)(Ast)(Gram)(Quotation)
    module AstFilters = Struct.AstFilters.Make(Ast)
    module MakeGram = Struct.Grammar.Static.Make
    module Printers =
      struct
        module OCaml = Printers.OCaml.Make(Syntax)
        module OCamlr = Printers.OCamlr.Make(Syntax)
        module DumpOCamlAst = Printers.DumpOCamlAst.Make(Syntax)
        module DumpCamlp4Ast = Printers.DumpCamlp4Ast.Make(Syntax)
        module Null = Printers.Null.Make(Syntax)
      end
  end
module Register :
  sig
    module Plugin
      (Id : Sig.Id) (Plugin : functor (Unit : sig  end) -> sig  end) :
      sig  end
    module SyntaxPlugin
      (Id : Sig.Id) (SyntaxPlugin : functor (Syn : Sig.Syntax) -> sig  end) :
      sig  end
    module SyntaxExtension
      (Id : Sig.Id) (SyntaxExtension : Sig.SyntaxExtension) : sig  end
    module OCamlSyntaxExtension
      (Id : Sig.Id)
      (SyntaxExtension :
        functor (Syntax : Sig.Camlp4Syntax) -> Sig.Camlp4Syntax) :
      sig  end
    type 'a parser_fun =
      ?directive_handler: ('a -> 'a option) ->
        PreCast.Loc.t -> char Stream.t -> 'a
    val register_str_item_parser : PreCast.Ast.str_item parser_fun -> unit
    val register_sig_item_parser : PreCast.Ast.sig_item parser_fun -> unit
    val register_parser :
      PreCast.Ast.str_item parser_fun ->
        PreCast.Ast.sig_item parser_fun -> unit
    module Parser
      (Id : Sig.Id)
      (Maker : functor (Ast : Sig.Ast) -> Sig.Parser with module Ast = Ast) :
      sig  end
    module OCamlParser
      (Id : Sig.Id)
      (Maker :
        functor (Ast : Sig.Camlp4Ast) -> Sig.Parser with module Ast = Ast) :
      sig  end
    module OCamlPreCastParser
      (Id : Sig.Id) (Parser : Sig.Parser with module Ast = PreCast.Ast) :
      sig  end
    type 'a printer_fun =
      ?input_file: string -> ?output_file: string -> 'a -> unit
    val register_str_item_printer : PreCast.Ast.str_item printer_fun -> unit
    val register_sig_item_printer : PreCast.Ast.sig_item printer_fun -> unit
    val register_printer :
      PreCast.Ast.str_item printer_fun ->
        PreCast.Ast.sig_item printer_fun -> unit
    module Printer
      (Id : Sig.Id)
      (Maker :
        functor (Syn : Sig.Syntax) -> Sig.Printer with module Ast = Syn.Ast) :
      sig  end
    module OCamlPrinter
      (Id : Sig.Id)
      (Maker :
        functor (Syn : Sig.Camlp4Syntax) ->
          Sig.Printer with module Ast = Syn.Ast) :
      sig  end
    module OCamlPreCastPrinter
      (Id : Sig.Id) (Printer : Sig.Printer with module Ast = PreCast.Ast) :
      sig  end
    module AstFilter
      (Id : Sig.Id) (Maker : functor (F : Sig.AstFilters) -> sig  end) :
      sig  end
    val declare_dyn_module : string -> (unit -> unit) -> unit
    val iter_and_take_callbacks : ((string * (unit -> unit)) -> unit) -> unit
    module CurrentParser : Sig.Parser with module Ast = PreCast.Ast
    module CurrentPrinter : Sig.Printer with module Ast = PreCast.Ast
    val enable_ocaml_printer : unit -> unit
    val enable_ocamlr_printer : unit -> unit
    val enable_null_printer : unit -> unit
    val enable_dump_ocaml_ast_printer : unit -> unit
    val enable_dump_camlp4_ast_printer : unit -> unit
  end =
  struct
    module PP = Printers
    open PreCast
    type 'a parser_fun =
      ?directive_handler: ('a -> 'a option) ->
        PreCast.Loc.t -> char Stream.t -> 'a
    type 'a printer_fun =
      ?input_file: string -> ?output_file: string -> 'a -> unit
    let sig_item_parser =
      ref (fun ?directive_handler:(_) _ _ -> failwith "No interface parser")
    let str_item_parser =
      ref
        (fun ?directive_handler:(_) _ _ ->
           failwith "No implementation parser")
    let sig_item_printer =
      ref
        (fun ?input_file:(_) ?output_file:(_) _ ->
           failwith "No interface printer")
    let str_item_printer =
      ref
        (fun ?input_file:(_) ?output_file:(_) _ ->
           failwith "No implementation printer")
    let callbacks = Queue.create ()
    let iter_and_take_callbacks f =
      let rec loop () = loop (f (Queue.take callbacks))
      in try loop () with | Queue.Empty -> ()
    let declare_dyn_module m f = Queue.add (m, f) callbacks
    let register_str_item_parser f = str_item_parser := f
    let register_sig_item_parser f = sig_item_parser := f
    let register_parser f g = (str_item_parser := f; sig_item_parser := g)
    let register_str_item_printer f = str_item_printer := f
    let register_sig_item_printer f = sig_item_printer := f
    let register_printer f g = (str_item_printer := f; sig_item_printer := g)
    module Plugin
      (Id : Sig.Id) (Maker : functor (Unit : sig  end) -> sig  end) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(struct  end) in ())
      end
    module SyntaxExtension (Id : Sig.Id) (Maker : Sig.SyntaxExtension) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(Syntax) in ())
      end
    module OCamlSyntaxExtension
      (Id : Sig.Id)
      (Maker : functor (Syn : Sig.Camlp4Syntax) -> Sig.Camlp4Syntax) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(Syntax) in ())
      end
    module SyntaxPlugin
      (Id : Sig.Id) (Maker : functor (Syn : Sig.Syntax) -> sig  end) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(Syntax) in ())
      end
    module Printer
      (Id : Sig.Id)
      (Maker :
        functor (Syn : Sig.Syntax) -> Sig.Printer with module Ast = Syn.Ast) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(Syntax)
               in register_printer M.print_implem M.print_interf)
      end
    module OCamlPrinter
      (Id : Sig.Id)
      (Maker :
        functor (Syn : Sig.Camlp4Syntax) ->
          Sig.Printer with module Ast = Syn.Ast) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(Syntax)
               in register_printer M.print_implem M.print_interf)
      end
    module OCamlPreCastPrinter
      (Id : Sig.Id) (P : Sig.Printer with module Ast = PreCast.Ast) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> register_printer P.print_implem P.print_interf)
      end
    module Parser
      (Id : Sig.Id)
      (Maker : functor (Ast : Sig.Ast) -> Sig.Parser with module Ast = Ast) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(PreCast.Ast)
               in register_parser M.parse_implem M.parse_interf)
      end
    module OCamlParser
      (Id : Sig.Id)
      (Maker :
        functor (Ast : Sig.Camlp4Ast) -> Sig.Parser with module Ast = Ast) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(PreCast.Ast)
               in register_parser M.parse_implem M.parse_interf)
      end
    module OCamlPreCastParser
      (Id : Sig.Id) (P : Sig.Parser with module Ast = PreCast.Ast) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> register_parser P.parse_implem P.parse_interf)
      end
    module AstFilter
      (Id : Sig.Id) (Maker : functor (F : Sig.AstFilters) -> sig  end) =
      struct
        let _ =
          declare_dyn_module Id.name
            (fun _ -> let module M = Maker(AstFilters) in ())
      end
    let _ = let module M = Syntax.Parser
      in
        (sig_item_parser := M.parse_interf;
         str_item_parser := M.parse_implem)
    module CurrentParser =
      struct
        module Ast = Ast
        let parse_interf ?directive_handler loc strm =
          !sig_item_parser ?directive_handler loc strm
        let parse_implem ?directive_handler loc strm =
          !str_item_parser ?directive_handler loc strm
      end
    module CurrentPrinter =
      struct
        module Ast = Ast
        let print_interf ?input_file ?output_file ast =
          !sig_item_printer ?input_file ?output_file ast
        let print_implem ?input_file ?output_file ast =
          !str_item_printer ?input_file ?output_file ast
      end
    let enable_ocaml_printer () =
      let module M = OCamlPrinter(PP.OCaml.Id)(PP.OCaml.MakeMore) in ()
    let enable_ocamlr_printer () =
      let module M = OCamlPrinter(PP.OCamlr.Id)(PP.OCamlr.MakeMore) in ()
    let enable_dump_ocaml_ast_printer () =
      let module M = OCamlPrinter(PP.DumpOCamlAst.Id)(PP.DumpOCamlAst.Make)
      in ()
    let enable_dump_camlp4_ast_printer () =
      let module M = Printer(PP.DumpCamlp4Ast.Id)(PP.DumpCamlp4Ast.Make)
      in ()
    let enable_null_printer () =
      let module M = Printer(PP.Null.Id)(PP.Null.Make) in ()
  end
