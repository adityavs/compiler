{-# OPTIONS_GHC -W #-}
{-# LANGUAGE FlexibleContexts #-}
module Metadata.Prelude (add) where

import qualified Data.Map as Map
import qualified Data.Set as Set

import qualified AST.Module as Module
import qualified AST.Variable as Var


-- DEFINITION OF THE PRELUDE

type ImportDict =
    Map.Map Module.Name ([String], Var.Listing Var.Value)


prelude :: ImportDict
prelude =
    Map.unions [ string, text, maybe, openImports ]
  where
    importing :: Module.Name -> [Var.Value] -> ImportDict
    importing name values =
        Map.singleton name ([], Var.Listing values False)

    openImports :: ImportDict
    openImports =
        Map.fromList $ map (\name -> (name, ([], Var.openListing))) $
        [ ["Basics"], ["Signal"], ["List"], ["Time"], ["Color"]
        , ["Graphics","Element"], ["Graphics","Collage"]
        , ["Native","Ports"], ["Native","Json"]
        ]

    maybe :: ImportDict
    maybe = importing ["Maybe"] [ Var.ADT "Maybe" Var.openListing ]

    string :: ImportDict
    string = importing ["String"] [Var.Value "show"]

    text :: ImportDict
    text = importing ["Text"] (Var.ADT "Text" (Var.Listing [] False) : values)
      where
        values =
            map Var.Value
            [ "toText", "leftAligned", "rightAligned", "centered", "justified"
            , "plainText", "asText", "typeface", "monospace", "bold", "italic"
            ]


-- ADDING PRELUDE TO A MODULE

add :: Bool -> Module.Module exs body -> Module.Module exs body
add noPrelude (Module.Module moduleName path exports imports decls) =
    Module.Module moduleName path exports ammendedImports decls
  where
    ammendedImports =
      importDictToList $
        foldr addImport (if noPrelude then Map.empty else prelude) imports


importDictToList :: ImportDict -> [(Module.Name, Module.ImportMethod)]
importDictToList dict =
    concatMap toImports (Map.toList dict)
  where
    toImports (name, (qualifiers, listing@(Var.Listing explicits open))) =
        map (\qualifier -> (name, Module.As qualifier)) qualifiers
        ++
        if open || not (null explicits)
          then [(name, Module.Open listing)]
          else []


addImport :: (Module.Name, Module.ImportMethod) -> ImportDict -> ImportDict
addImport (name, method) importDict =
    Map.alter mergeMethods name importDict
  where
    mergeMethods :: Maybe ([String], Var.Listing Var.Value)
                 -> Maybe ([String], Var.Listing Var.Value)
    mergeMethods entry =
      let (qualifiers, listing) =
              case entry of
                Nothing -> ([], Var.Listing [] False)
                Just v -> v
      in
          case method of
            Module.As qualifier ->
                Just (qualifier : qualifiers, listing)

            Module.Open newListing ->
                Just (qualifiers, mergeListings newListing listing)

    mergeListings (Var.Listing explicits1 open1) (Var.Listing explicits2 open2) =
        Var.Listing
          (Set.toList (Set.fromList (explicits1 ++ explicits2)))
          (open1 || open2)
