{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -ddump-splices #-}
module Main (main) where

import Test.Tasty
import Test.Tasty.Providers (singleTest)
import Test.QuickCheck.Monadic (monadicIO, run, assert)
import Test.Tasty.QuickCheck (QC(QC))
import Test.QuickCheck

import Calc (calc)
import Calc.Value (showRational)

import Utils (testCalc, convertToRational)

main :: IO ()
main = defaultMain tests


tests :: TestTree
tests = testGroup "Tests" [withoutUnits, withUnits, unitConversion, unitCast]


withoutUnits :: TestTree
withoutUnits = testGroup "Without units" [
  $(testCalc "$a + $>=0b" [| (+) |] ""),
  $(testCalc "$a - $>=0b" [| (-) |] ""),
  $(testCalc "$a * $>=0b" [| (*) |] ""),
  $(testCalc "$a / $>0b" [| (/) |] ""),

  $(testCalc "$a+$>=0b" [| (+) |] ""),
  $(testCalc "$a-$>=0b" [| (-) |] ""),
  $(testCalc "$a*$>=0b" [| (*) |] ""),
  $(testCalc "$a/$>0b" [| (/) |] ""),

  $(testCalc "$a + $>=0b + $>=0c" [| \a b c -> a + b + c |] ""),
  $(testCalc "$a - $>=0b - $>=0c" [| \a b c -> a - b - c |] ""),
  $(testCalc "$a * $>=0b * $>=0c" [| \a b c -> a * b * c |] ""),
  $(testCalc "$a / $>0b / $>0c" [| \a b c -> a / b / c |] ""),
  
  $(testCalc "$a + $>=0b * $>=0c" [| \a b c -> a + b * c |] ""),
  $(testCalc "$a * $>=0b + $>=0c" [| \a b c -> a * b + c |] ""),
  $(testCalc "($a + $>=0b) * $>=0c" [| \a b c -> (a + b) * c |] ""),
  $(testCalc "$a * ($b + $>=0c)" [| \a b c -> a * (b + c) |] "")]


withUnits :: TestTree
withUnits = testGroup "With units" [
  $(testCalc "$am + $>=0bm" [| (+) |] " m"),
  $(testCalc "$am - $>=0bm" [| (-) |] " m"),
  $(testCalc "$am * $>=0bm" [| (*) |] " m^2"),
  $(testCalc "$am / $>0bm" [| (/) |] ""),
  $(testCalc "$a m/s^2" [| id |] " m/s^2"),
  $(testCalc "$a s^2 / $>0b s" [| (/) |] " s")]


unitConversion :: TestTree
unitConversion = testGroup "Unit conversion" [
  $(testCalc "$a kgm/s^2" [| id |] " N"),
  $(testCalc "$a kgm/s^2 * 1s" [| id |] " kgm/s"),
  $(testCalc "$a N/kg" [| id |] " m/s^2"),
  $(testCalc "$a km" [| (* 1000) |] " m"),
  $(testCalc "$a mm" [| (/ 1000) |] " m"),
  $(testCalc "$a min" [| (* 60) |] " s")]


unitCast :: TestTree
unitCast = testGroup "Unit cast" [
  $(testCalc "$ag [kg]" [| (/ 1000) |] " kg"),
  $(testCalc "$as[min]" [| (/ 60) |] " min"),
  $(testCalc "$a m/s^2 [N/kg]" [| id |] " N/kg")]