-- Copyright 2019 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

module ParseUtil (sc, blankLines, stringLiteral, failIf,
                  space, num, uint, lexeme, symbol, parens, brackets, Parser,
                  emptyLines, nonBlankLines, outputLines, withPos, withSource,
                  getLineNum) where

import Control.Monad
import Data.Void
import Text.Megaparsec
import Text.Megaparsec.Char hiding (space)
import qualified Text.Megaparsec.Char.Lexer as L


type Parser = Parsec Void String

sc :: Parser ()
sc = L.space space (L.skipLineComment "--") empty

blankLines :: Parser ()
blankLines = void $ many eol

nonBlankLines :: Parser ()
nonBlankLines = void $ many $ takeWhile1P Nothing (/= '\n') >> eol

emptyLines :: Parser ()
emptyLines = void $ many (sc >> eol)

outputLines :: Parser ()
outputLines = void $ many (symbol ">" >> takeWhileP Nothing (/= '\n') >> eol)

stringLiteral :: Parser String
stringLiteral = char '"' >> manyTill L.charLiteral (char '"') <* sc

space :: Parser ()
space = void $ do _ <- takeWhile1P (Just "white space") (`elem` " \t")
                  optional (lexeme (symbol "..") >> eol)

num :: Parser (Either Double Int)
num =    liftM Left (try (L.signed (return ()) L.float) <* sc)
     <|> (do x <- L.signed (return ()) L.decimal
             trailingPeriod <- optional (char '.')
             sc
             return $ case trailingPeriod of
               Just _  -> Left (fromIntegral x)
               Nothing -> Right x)

uint :: Parser Int
uint = L.decimal <* sc

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: String -> Parser ()
symbol s = void $ L.symbol sc s

parens :: Parser a -> Parser a
parens = between (symbol "(") (symbol ")")

brackets :: Parser a -> Parser a
brackets = between (symbol "[") (symbol "]")

withPos :: Parser a -> Parser (a, (Int, Int))
withPos p = do
  n <- getOffset
  x <- p
  n' <- getOffset
  return $ (x, (n, n'))

withSource :: Parser a -> Parser (String, a)
withSource p = do
  s <- getInput
  (x, (start, end)) <- withPos p
  return (take (end - start) s, x)

getLineNum :: Parser Int
getLineNum = liftM (unPos . sourceLine) getSourcePos

failIf :: Bool -> String -> Parser ()
failIf True s = fail s
failIf False _ = return ()
