(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt

module Contents = Ir_contents
module Merge = Ir_merge
module Tag = Ir_tag
module Task = Ir_task
module View = Ir_view.Make
module Snapshot = Ir_snapshot.Make
module Dot = Ir_dot.Make
module type S = Ir_s.STORE

module Hash = Ir_hash
module Path = Ir_path
module Make = Ir_s.Make
module Make_ext = Ir_s.Make_ext

module type RO = Ir_ro.STORE
module type AO = Ir_ao.STORE
module type RW = Ir_rw.STORE
module type HRW = Ir_rw.HIERARCHICAL
module type BC = Ir_bc.STORE
module Hum = Ir_hum

type task = Task.t
type config = Ir_conf.t

module type AO_MAKER = Ir_ao.MAKER
module type RW_MAKER = Ir_rw.MAKER
module type BC_MAKER = Ir_bc.MAKER
module type S_MAKER = Ir_s.MAKER

module Private = struct
  module Conf = Ir_conf
  module Node = Ir_node
  module Commit = Ir_commit
  module Slice = Ir_slice
  module Make = Ir_bc.Make
  module Sync = Ir_sync
  module type S = Ir_bc.PRIVATE
  module Watch = Ir_watch
end

let version = Ir_version.current

module Sync = Ir_sync_ext.Make

type remote = Ir_sync_ext.remote

let remote_store (type t) (module M: S with type t = t) (t:t) =
  let module X = (M: Ir_s.STORE with type t = t) in
  Ir_sync_ext.remote_store (module X) t

let remote_uri = Ir_sync_ext.remote_uri

module type BASIC = S with type tag = string and type head = Hash.SHA1.t

module Basic = Ir_s.Default

type ('a, 'b) basic = (module BASIC with type key = 'a and type value = 'b)

type ('a, 'b) contents =
  (module Contents.S with type Path.t = 'a and type t = 'b)

let basic (type k) (type v)
    (module B: S_MAKER)
    (module C: Contents.S with type Path.t = k and type t = v)
  : (k, v) basic
  =
  let module B = Basic(B)(C) in
  (module B)

module type T = S with type tag = string and type head = Hash.SHA1.t

type ('a, 'b) t =
    T: (module T with type key = 'a and type value = 'b and type t = 't) * 't
    -> ('a, 'b) t

let create (type a) (type b) (t: (a, b) basic) config task =
  let (module T) = t in
  T.create config task >>= fun t ->
  return (fun a -> T ((module T), t a))

let of_tag (type a) (type b) (t: (a, b) basic) config task tag =
  let (module T) = t in
  T.of_tag config task tag >>= fun t ->
  return (fun a -> T ((module T), t a))

let of_head (type a) (type b) (t: (a, b) basic) config task h =
  let (module T) = t in
  T.of_head config task h >>= fun t ->
  return (fun a -> T ((module T), t a))

let read (type a) (type b): (a, b) t -> a -> b option Lwt.t =
  function T ((module M), t) -> M.read t

let read_exn (type a) (type b): (a, b) t -> a -> b Lwt.t =
  function T ((module M), t) -> M.read_exn t

let mem (type a) (type b): (a, b) t -> a -> bool Lwt.t =
  function T ((module M), t) -> M.mem t

let iter (type a) (type b): (a, b) t -> (a -> unit Lwt.t) -> unit Lwt.t =
  function T ((module M), t) -> M.iter t

let update (type a) (type b): (a, b) t -> a -> b -> unit Lwt.t =
  function T ((module M), t) -> M.update t

let remove (type a) (type b): (a, b) t -> a -> unit Lwt.t =
  function T ((module M), t) -> M.remove t

let watch (type a) (type b): (a, b) t -> a -> b option Lwt_stream.t =
  function T ((module M), t) -> M.watch t

let list (type a) (type b): (a, b) t -> a -> a list Lwt.t =
  function T ((module M), t) -> M.list t

let remove_rec (type a) (type b): (a, b) t -> a -> unit Lwt.t =
  function T ((module M), t) -> M.remove_rec t

let tag (type a) (type b): (a, b) t -> string option =
  function T ((module M), t) -> M.tag t

let tag_exn (type a) (type b): (a, b) t -> string =
  function T ((module M), t) -> M.tag_exn t

let tags (type a) (type b): (a, b) t -> string list Lwt.t =
  function T ((module M), t) -> M.tags t

let rename_tag (type a) (type b): (a, b) t -> string -> [`Ok | `Duplicated_tag] Lwt.t =
  function T ((module M), t) -> M.rename_tag t

let update_tag (type a) (type b): (a, b) t -> string -> unit Lwt.t =
  function T ((module M), t) -> M.update_tag t

let merge_tag (type a) (type b): (a, b) t -> string -> unit Merge.result Lwt.t =
  function T ((module M), t) -> M.merge_tag t

let merge_tag_exn (type a) (type b): (a, b) t -> string -> unit Lwt.t =
  function T ((module M), t) -> M.merge_tag_exn t

let switch (type a) (type b): (a, b) t -> string -> unit Lwt.t =
  function T ((module M), t) -> M.switch t

let head (type a) (type b): (a, b) t -> Hash.SHA1.t option Lwt.t =
  function T ((module M), t) -> M.head t

let head_exn (type a) (type b): (a, b) t -> Hash.SHA1.t Lwt.t =
  function T ((module M), t) -> M.head_exn t

let branch (type a) (type b): (a, b) t -> [`Tag of string | `Head of Hash.SHA1.t] =
  function T ((module M), t) -> M.branch t

let heads (type a) (type b): (a, b) t -> Hash.SHA1.t list Lwt.t =
  function T ((module M), t) -> M.heads t

let detach (type a) (type b): (a, b) t -> unit Lwt.t =
  function T ((module M), t) -> M.detach t

let update_head (type a) (type b): (a, b) t -> Hash.SHA1.t -> unit Lwt.t =
  function T ((module M), t) -> M.update_head t

let merge_head (type a) (type b):
  (a, b) t -> Hash.SHA1.t -> unit Merge.result Lwt.t =
  function T ((module M), t) -> M.merge_head t

let merge_head_exn (type a) (type b): (a, b) t -> Hash.SHA1.t -> unit Lwt.t =
  function T ((module M), t) -> M.merge_head_exn t

let watch_head (type a) (type b):
  (a, b) t -> a -> (a * Hash.SHA1.t) Lwt_stream.t =
  function T ((module M), t) -> M.watch_head t

let clone (type a) (type b):
  ('m -> task) -> (a, b) t -> string ->
  [`Ok of ('m -> (a, b) t) | `Duplicated_tag] Lwt.t =
  fun x t y -> match t with
    | T ((module M), t) ->
      M.clone x t y >>= function
      | `Ok t -> return (`Ok (fun a -> T ((module M), t a)))
      | `Duplicated_tag -> return `Duplicated_tag

let clone_force (type a) (type b):
  ('m -> task) -> (a, b) t -> string -> ('m -> (a, b) t) Lwt.t =
  fun x t y -> match t with
    | T ((module M), t) ->
      M.clone_force x t y >>= fun t ->
      return (fun a -> T ((module M), t a))

let merge (type a) (type b):
  'a -> ('a -> (a, b) t) -> into:('a -> (a, b) t) -> unit Merge.result Lwt.t =
  fun a t ~into -> match t a, into a with
    | T ((module M), t), T ((module I), into) ->
      (* XXX: not ideal ... *)
      match M.branch t with
      | `Tag tag -> I.merge_tag into tag
      | `Head h  -> I.merge_head into h

let merge_exn (type a) (type b):
  'a -> ('a -> (a, b) t) -> into:('a -> (a, b) t) -> unit Lwt.t =
  fun a t ~into -> merge a t ~into >>= Merge.exn

let lca (type a) (type b):
  'a -> ('a -> (a, b) t) -> ('a -> (a, b) t) -> Hash.SHA1.t list Lwt.t =
  fun a t1 t2 -> match t1 a, t2 a with
    | T ((module M), t1), T ((module I), t2) ->
      (* XXX: not ideal ... *)
      match I.branch t2 with
      | `Tag tag -> M.lca_tag t1 tag
      | `Head h  -> M.lca_head t1 h

let lca_tag (type a) (type b) (t: (a, b) t) = match t with
  | T ((module M), t) -> M.lca_tag t

let lca_head (type a) (type b) (t: (a, b) t) = match t with
  | T ((module M), t) -> M.lca_head t

let task_of_head (type a) (type b) (t: (a, b) t) = match t with
  | T ((module M), t) -> M.task_of_head t

let remote_basic (type a) (type b): (a, b) t -> remote =
  function T ((module M), t) -> remote_store (module M) t

let fetch (type a) (type b):
  (a, b) t -> ?depth:int -> remote -> Hash.SHA1.t option Lwt.t =
  fun t ?depth remote -> match t with
    | T ((module M), t) ->
      let module S = Sync(M) in
      S.fetch t ?depth remote

let fetch_exn (type a) (type b):
  (a, b) t -> ?depth:int -> remote -> Hash.SHA1.t Lwt.t =
  fun t ?depth remote -> match t with
    | T ((module M), t) ->
      let module S = Sync(M) in
      S.fetch_exn t ?depth remote

let pull (type a) (type b):
  (a, b) t -> ?depth:int -> remote -> [`Merge | `Update] ->
  unit Merge.result Lwt.t =
  fun t ?depth remote k -> match t with
    | T ((module M), t) ->
      let module S = Sync(M) in
      S.pull t ?depth remote k

let pull_exn (type a) (type b):
  (a, b) t -> ?depth:int -> remote -> [`Merge | `Update] -> unit Lwt.t =
  fun t ?depth remote k -> match t with
    | T ((module M), t) ->
      let module S = Sync(M) in
      S.pull_exn t ?depth remote k

let push (type a) (type b):
  (a, b) t -> ?depth:int -> remote -> [`Ok | `Error] Lwt.t =
  fun t ?depth remote -> match t with
    | T ((module M), t) ->
      let module S = Sync(M) in
      S.push t ?depth remote

let push_exn (type a) (type b):
  (a, b) t -> ?depth:int -> remote -> unit Lwt.t =
  fun t ?depth remote -> match t with
    | T ((module M), t) ->
      let module S = Sync(M) in
      S.push_exn t ?depth remote

type 'a proj = < f: 't . (module S with type t = 't) -> 't -> 'a >

let with_store (type a) (type b): (a,b) t -> 'a proj -> 'a =
  fun t f -> match t with
    | T ((module M), t) -> f#f (module M) t
