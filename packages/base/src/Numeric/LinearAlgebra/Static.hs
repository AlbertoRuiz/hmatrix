{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoStarIsType #-}


{- |
Module      :  Numeric.LinearAlgebra.Static
Copyright   :  (c) Alberto Ruiz 2014
License     :  BSD3
Stability   :  experimental

Experimental interface with statically checked dimensions.

See code examples at http://dis.um.es/~alberto/hmatrix/static.html.

-}

module Numeric.LinearAlgebra.Static(
    -- * Vector
       ℝ, R,
    -- * Matrix
    L, Sq,
    tr,
    -- * Complex
    ℂ, C, M, Her, her, 𝑖,
    toComplex,
    fromComplex,
    complex,
    real,
    imag,
    sqMagnitude,
    magnitude,
    -- * Factorizations
    svd, withCompactSVD, svdTall, svdFlat, Eigen(..),
    withNullspace, withOrth, qr, chol,
    -- * Norms
    Normed(..),
    -- * Random arrays
    Seed, RandDist(..),
    randomVector, rand, randn, gaussianSample, uniformSample,
    -- * Misc
    Disp(..), Domain(..),
    Sized(..), Diag(..), Sym, sym, mTm, unSym,
) where


import GHC.TypeLits
import Numeric.LinearAlgebra hiding (
    (<>),(#>),(<.>),Konst(..),diag, disp,(===),(|||),
    row,col,vector,matrix,linspace,toRows,toColumns,
    (<\>),fromList,takeDiag,svd,eig,eigSH,
    eigenvalues,eigenvaluesSH,build,
    qr,size,dot,chol,range,R,C,sym,mTm,unSym,
    randomVector,rand,randn,gaussianSample,uniformSample,meanCov,
    toComplex, fromComplex, complex, real, magnitude, diag
    )
import qualified Numeric.LinearAlgebra as LA
import qualified Numeric.LinearAlgebra.Static.Real as R
import qualified Numeric.LinearAlgebra.Static.Complex as C
import Data.Proxy(Proxy(..))
import Internal.Static
import Text.Printf
#if MIN_VERSION_base(4,11,0)
import Prelude hiding ((<>))
import Data.Finite (Finite)
#endif


class Domain field vec mat | mat -> vec field, vec -> mat field, field -> mat vec
  where

    mul :: forall m k n. (KnownNat m, KnownNat k, KnownNat n) => mat m k -> mat k n -> mat m n
    app :: forall m n . (KnownNat m, KnownNat n) => mat m n -> vec n -> vec m
    dot :: forall n . (KnownNat n) => vec n -> vec n -> field
    infixr 8 <>
    (<>) :: forall m k n. (KnownNat m, KnownNat k, KnownNat n) => mat m k -> mat k n -> mat m n
    infixr 8 #>
    (#>) :: (KnownNat m, KnownNat n) => mat m n -> vec n -> vec m
    infixr 8 <·>
    (<·>) :: KnownNat n => vec n -> vec n -> field
    infixr 8 <.>
    (<.>) :: KnownNat n => vec n -> vec n -> field

    cross :: vec 3 -> vec 3 -> vec 3
    diag ::  forall n . KnownNat n => vec n -> mat n n
    diagR ::  forall m n k . (KnownNat m, KnownNat n, KnownNat k) => field -> vec k -> mat m n
    eye :: forall n. KnownNat n => mat n n
    dvmap :: forall n. KnownNat n => (field -> field) -> vec n -> vec n
    dmmap :: forall n m. (KnownNat m, KnownNat n) => (field -> field) -> mat n m -> mat n m
    outer :: forall n m. (KnownNat m, KnownNat n) => vec n -> vec m -> mat n m
    zipWithVector :: forall n. KnownNat n => (field -> field -> field) -> vec n -> vec n -> vec n

    isKonst :: forall m n . (KnownNat m, KnownNat n) => mat m n -> Maybe (field,(Int,Int))
    isKonstV :: forall n . KnownNat n => vec n -> Maybe (field,Int)

    vector :: KnownNat n => [field] -> vec n
    matrix :: (KnownNat m, KnownNat n) => [field] -> mat m n
    split :: forall p n . (KnownNat p, KnownNat n, p<=n) => vec n -> (vec p, vec (n-p))
    splitRows :: forall p m n . (KnownNat p, KnownNat m, KnownNat n, p<=m) => mat m n -> (mat p n, mat (m-p) n)
    splitCols :: forall p m n. (KnownNat p, KnownNat m, KnownNat n, KnownNat (n-p), p<=n) => mat m n -> (mat m p, mat m (n-p))
    headTail :: (KnownNat n, 1<=n) => vec n -> (field, vec (n-1))

    toRows :: forall m n . (KnownNat m, KnownNat n) => mat m n -> [vec n]
    withRows :: forall n z . KnownNat n => [vec n] -> (forall m . KnownNat m => mat m n -> z) -> z
    toColumns :: forall m n . (KnownNat m, KnownNat n) => mat m n -> [vec m]
    withColumns :: forall m z . KnownNat m => [vec m] -> (forall n . KnownNat n => mat m n -> z) -> z

    det :: forall n. KnownNat n => mat n n -> field
    invlndet :: forall n. KnownNat n => mat n n -> (mat n n, (field, field))
    expm :: forall n. KnownNat n => mat n n -> mat n n
    sqrtm :: forall n. KnownNat n => mat n n -> mat n n
    inv :: forall n. KnownNat n => mat n n -> mat n n
    infixl 7 <\>
    (<\>) :: (KnownNat m, KnownNat n, KnownNat r) => mat m n -> mat m r -> mat n r
    linSolve :: (KnownNat m, KnownNat n) => mat m m -> mat m n -> Maybe (mat m n)

    build :: forall m n . (KnownNat n, KnownNat m) => (field -> field -> field) -> mat m n
    vec2 :: field -> field -> vec 2
    vec3 :: field -> field -> field -> vec 3
    vec4 :: field -> field -> field -> field -> vec 4
    row :: KnownNat n => vec n -> mat 1 n
    unrow :: KnownNat n => mat 1 n -> vec n
    col :: KnownNat n => vec n -> mat n 1
    uncol :: KnownNat n => mat n 1 -> vec n
    infixl 2 ===
    (===) :: (KnownNat r1, KnownNat r2, KnownNat c) => mat r1 c -> mat r2 c -> mat (r1+r2) c
    (|||) :: (KnownNat r, KnownNat c1, KnownNat c2, KnownNat (c1+c2)) => mat r c1 -> mat r c2 -> mat r (c1+c2)
    infixl 4 #
    (#) :: forall n m . (KnownNat n, KnownNat m) => vec n -> vec m -> vec (n+m)
    infixl 4 &
    (&) :: forall n . KnownNat n => vec n -> field -> vec (n+1)
    flatten :: (KnownNat m, KnownNat n, KnownNat (m * n)) => mat m n -> vec (m * n)
    reshape :: (KnownNat m, KnownNat n, KnownNat k, n ~ (k * m)) => vec n -> mat k m

    linspace :: forall n . KnownNat n => (field,field) -> vec n
    range :: forall n . KnownNat n => vec n
    dim :: forall n . KnownNat n => vec n
    mean :: (KnownNat n, 1<=n) => vec n -> field

    withVector :: forall z . Vector field -> (forall n . (KnownNat n) => vec n -> z) -> z
    exactLength :: forall n m . (KnownNat n, KnownNat m) => vec m -> Maybe (vec n)
    withMatrix :: forall z . Matrix field -> (forall m n . (KnownNat m, KnownNat n) => mat m n -> z) -> z
    exactDims :: forall n m j k . (KnownNat n, KnownNat m, KnownNat j, KnownNat k) => mat m n -> Maybe (mat j k)

    blockAt :: forall m n . (KnownNat m, KnownNat n) => field -> Int -> Int -> Matrix field -> mat m n

    vAt :: forall n. KnownNat n => vec n -> Finite n -> field
    mAt :: forall m n. (KnownNat m, KnownNat n) => mat m n -> Finite m -> Finite n -> field

--------------------------------------------------------------------------------

instance Domain ℝ R L
  where
    mul = R.mul
    app = R.app
    dot = R.dot
    (<>) = mul
    (#>) = app
    (<·>) = dot
    (<.>) = dot

    cross = R.cross
    diag  = R.diag
    diagR = R.diagR
    eye   = R.eye
    dvmap = R.mapR
    dmmap = R.mapL
    outer = R.outer
    zipWithVector = R.zipWith

    isKonst = R.isKonst
    isKonstV = R.isKonstV

    vector = fromList
    matrix = fromList
    split = R.split
    splitRows = R.splitRows
    splitCols = R.splitCols
    headTail = R.headTail

    toRows = R.toRows
    withRows = R.withRows
    toColumns = R.toColumns
    withColumns  = R.withColumns

    det = R.det
    invlndet = R.invlndet
    expm = R.expm
    sqrtm = R.sqrtm
    inv = R.inv
    (<\>) = (R.<\>)
    linSolve = R.linSolve

    build = R.build
    vec2 = R.vec2
    vec3 = R.vec3
    vec4 = R.vec4
    row = R.row
    unrow = R.unrow
    col = R.col
    uncol = R.uncol
    (===) = (R.===)
    (|||) = (R.|||)
    (#) = (R.#)
    (&) = (R.&)
    flatten = R.flatten
    reshape = R.reshape

    linspace = R.linspace
    range = R.range
    dim = R.dim
    mean = R.mean

    withVector  = R.withVector
    exactLength = R.exactLength
    withMatrix = R.withMatrix
    exactDims = R.exactDims

    blockAt = R.blockAt

    vAt = R.vAt
    mAt = R.mAt

instance Domain ℂ C M
  where
    mul = C.mul
    app = C.app
    dot = C.dot
    (<>) = mul
    (#>) = app
    (<·>) = dot
    (<.>) = dot

    cross = C.cross
    diag  = C.diag
    diagR = C.diagR
    eye   = C.eye
    dvmap = C.mapC
    dmmap = C.mapM
    outer = C.outer
    zipWithVector = C.zipWith

    isKonst = C.isKonst
    isKonstV = C.isKonstV

    vector = fromList
    matrix = fromList
    split = C.split
    splitRows = C.splitRows
    splitCols = C.splitCols
    headTail = C.headTail

    toRows = C.toRows
    withRows = C.withRows
    toColumns = C.toColumns
    withColumns  = C.withColumns

    det = C.det
    invlndet = C.invlndet
    expm = C.expm
    sqrtm = C.sqrtm
    inv = C.inv
    (<\>) = (C.<\>)
    linSolve = C.linSolve

    build = C.build
    vec2 = C.vec2
    vec3 = C.vec3
    vec4 = C.vec4
    row = C.row
    unrow = C.unrow
    col = C.col
    uncol = C.uncol
    (===) = (C.===)
    (|||) = (C.|||)
    (#) = (C.#)
    (&) = (C.&)
    flatten = C.flatten
    reshape = C.reshape

    linspace = C.linspace
    range = C.range
    dim = C.dim
    mean = C.mean

    withVector  = C.withVector
    exactLength = C.exactLength
    withMatrix = C.withMatrix
    exactDims = C.exactDims

    blockAt = C.blockAt

    vAt = C.vAt
    mAt = C.mAt


--------------------------------------------------------------------------------

type Sq n  = L n n


class Diag m d | m -> d
  where
    takeDiag :: m -> d


instance KnownNat n => Diag (L n n) (R n)
  where
    takeDiag x = mkR (LA.takeDiag (extract x))


instance KnownNat n => Diag (M n n) (C n)
  where
    takeDiag x = mkC (LA.takeDiag (extract x))


--------------------------------------------------------------------------------


toComplex :: KnownNat n => (R n, R n) -> C n
toComplex (r,i) = mkC $ LA.toComplex (extract r, extract i)

fromComplex :: KnownNat n => C n -> (R n, R n)
fromComplex (C (Dim v)) = let (r,i) = LA.fromComplex v in (mkR r, mkR i)

complex :: KnownNat n => R n -> C n
complex r = mkC $ LA.toComplex (extract r, LA.konst 0 (size r))

real :: KnownNat n => C n -> R n
real = fst . fromComplex

imag :: KnownNat n => C n -> R n
imag = snd . fromComplex

sqMagnitude :: KnownNat n => C n -> R n
sqMagnitude c = let (r,i) = fromComplex c in r**2 + i**2

magnitude :: KnownNat n => C n -> R n
magnitude = sqrt . sqMagnitude


--------------------------------------------------------------------------------

svd :: (KnownNat m, KnownNat n) => L m n -> (L m m, R n, L n n)
svd (extract -> m) = (mkL u, mkR s', mkL v)
  where
    (u,s,v) = LA.svd m
    s' = vjoin [s, z]
    z = LA.konst 0 (max 0 (cols m - LA.size s))


svdTall :: (KnownNat m, KnownNat n, n <= m) => L m n -> (L m n, R n, L n n)
svdTall (extract -> m) = (mkL u, mkR s, mkL v)
  where
    (u,s,v) = LA.thinSVD m


svdFlat :: (KnownNat m, KnownNat n, m <= n) => L m n -> (L m m, R m, L n m)
svdFlat (extract -> m) = (mkL u, mkR s, mkL v)
  where
    (u,s,v) = LA.thinSVD m

--------------------------------------------------------------------------------

randomVector
    :: forall n . KnownNat n
    => Seed
    -> RandDist
    -> R n
randomVector s d = mkR (LA.randomVector s d
                          (fromInteger (natVal (Proxy :: Proxy n)))
                       )

rand
    :: forall m n . (KnownNat m, KnownNat n)
    => IO (L m n)
rand = mkL <$> LA.rand (fromInteger (natVal (Proxy :: Proxy m)))
                       (fromInteger (natVal (Proxy :: Proxy n)))

randn
    :: forall m n . (KnownNat m, KnownNat n)
    => IO (L m n)
randn = mkL <$> LA.randn (fromInteger (natVal (Proxy :: Proxy m)))
                         (fromInteger (natVal (Proxy :: Proxy n)))

gaussianSample
    :: forall m n . (KnownNat m, KnownNat n)
    => Seed
    -> R n
    -> Sym n
    -> L m n
gaussianSample s (extract -> mu) (Sym (extract -> sigma)) =
    mkL $ LA.gaussianSample s (fromInteger (natVal (Proxy :: Proxy m)))
                            mu (LA.trustSym sigma)

uniformSample
    :: forall m n . (KnownNat m, KnownNat n)
    => Seed
    -> R n    -- ^ minimums of each row
    -> R n    -- ^ maximums of each row
    -> L m n
uniformSample s (extract -> mins) (extract -> maxs) =
    mkL $ LA.uniformSample s (fromInteger (natVal (Proxy :: Proxy m)))
                           (zip (LA.toList mins) (LA.toList maxs))

--------------------------------------------------------------------------------

class Eigen m l v | m -> l, m -> v
  where
    eigensystem :: m -> (l,v)
    eigenvalues :: m -> l

instance KnownNat n => Eigen (Sym n) (R n) (L n n)
  where
    eigenvalues (Sym (extract -> m)) =  mkR . LA.eigenvaluesSH . LA.trustSym $ m
    eigensystem (Sym (extract -> m)) = (mkR l, mkL v)
      where
        (l,v) = LA.eigSH . LA.trustSym $ m

instance KnownNat n => Eigen (Sq n) (C n) (M n n)
  where
    eigenvalues (extract -> m) = mkC . LA.eigenvalues $ m
    eigensystem (extract -> m) = (mkC l, mkM v)
      where
        (l,v) = LA.eig m




sym :: KnownNat n => Sq n -> Sym n
sym m = Sym $ (m + tr m)/2

mTm :: (KnownNat m, KnownNat n) => L m n -> Sym n
mTm x = Sym (tr x <> x)

unSym :: Sym n -> Sq n
unSym (Sym x) = x



newtype Sym n = Sym (Sq n) deriving Show

instance (KnownNat n) => Disp (Sym n)
  where
    disp n (Sym x) = do
        let a = extract x
        let su = LA.dispf n a
        printf "Sym %d" (cols a) >> putStr (dropWhile (/='\n') $ su)



mkSym f = Sym . f . unSym
mkSym2 f x y = Sym (f (unSym x) (unSym y))

instance KnownNat n =>  Num (Sym n)
  where
    (+) = mkSym2 (+)
    (*) = mkSym2 (*)
    (-) = mkSym2 (-)
    abs = mkSym abs
    signum = mkSym signum
    negate = mkSym negate
    fromInteger = Sym . fromInteger

instance KnownNat n => Fractional (Sym n)
  where
    fromRational = Sym . fromRational
    (/) = mkSym2 (/)

instance KnownNat n => Floating (Sym n)
  where
    sin   = mkSym sin
    cos   = mkSym cos
    tan   = mkSym tan
    asin  = mkSym asin
    acos  = mkSym acos
    atan  = mkSym atan
    sinh  = mkSym sinh
    cosh  = mkSym cosh
    tanh  = mkSym tanh
    asinh = mkSym asinh
    acosh = mkSym acosh
    atanh = mkSym atanh
    exp   = mkSym exp
    log   = mkSym log
    sqrt  = mkSym sqrt
    (**)  = mkSym2 (**)
    pi    = Sym pi

instance KnownNat n => Additive (Sym n) where
    add = (+)

instance KnownNat n => Transposable (Sym n) (Sym n) where
    tr  = id
    tr' = id


chol :: KnownNat n => Sym n -> Sq n
chol (extract . unSym -> m) = mkL $ LA.chol $ LA.trustSym m

--------------------------------------------------------------------------------

withNullspace
    :: forall m n z . (KnownNat m, KnownNat n)
    => L m n
    -> (forall k . (KnownNat k) => L n k -> z)
    -> z
withNullspace (LA.nullspace . extract -> a) f =
    case someNatVal $ fromIntegral $ cols a of
       Nothing -> error "static/dynamic mismatch"
       Just (SomeNat (_ :: Proxy k)) -> f (mkL a :: L n k)

withOrth
    :: forall m n z . (KnownNat m, KnownNat n)
    => L m n
    -> (forall k. (KnownNat k) => L n k -> z)
    -> z
withOrth (LA.orth . extract -> a) f =
    case someNatVal $ fromIntegral $ cols a of
       Nothing -> error "static/dynamic mismatch"
       Just (SomeNat (_ :: Proxy k)) -> f (mkL a :: L n k)

withCompactSVD
    :: forall m n z . (KnownNat m, KnownNat n)
    => L m n
    -> (forall k . (KnownNat k) => (L m k, R k, L n k) -> z)
    -> z
withCompactSVD (LA.compactSVD . extract -> (u,s,v)) f =
    case someNatVal $ fromIntegral $ LA.size s of
       Nothing -> error "static/dynamic mismatch"
       Just (SomeNat (_ :: Proxy k)) -> f (mkL u :: L m k, mkR s :: R k, mkL v :: L n k)

--------------------------------------------------------------------------------

qr :: (KnownNat m, KnownNat n) => L m n -> (L m m, L m n)
qr (extract -> x) = (mkL q, mkL r)
  where
    (q,r) = LA.qr x


--------------------------------------------------------------------------------

𝑖 :: Sized ℂ s c => s
𝑖 = konst iC

newtype Her n = Her (M n n)


her :: KnownNat n => M n n -> Her n
her m = Her $ (m + LA.tr m)/2

instance KnownNat n => Transposable (Her n) (Her n) where
    tr          = id
    tr' (Her m) = Her (tr' m)

instance (KnownNat n) => Disp (Her n)
  where
    disp n (Her x) = do
        let a = extract x
        let su = LA.dispcf n a
        printf "Her %d" (cols a) >> putStr (dropWhile (/='\n') $ su)

--------------------------------------------------------------------------------
-- type GL = forall n m . (KnownNat n, KnownNat m) => L m n
-- type GSq = forall n . KnownNat n => Sq n

-- test :: (Bool, IO ())
-- test = (ok,info)
--   where
--     ok =   extract (eye :: Sq 5) == ident 5
--            && (unwrap .unSym) (mTm sm :: Sym 3) == tr ((3><3)[1..]) LA.<> (3><3)[1..]
--            && unwrap (tm :: L 3 5) == LA.matrix 5 [1..15]
--            && thingS == thingD
--            && precS == precD
--            && withVector (LA.vector [1..15]) sumV == sumElements (LA.fromList [1..15])

--     info = do
--         print $ u
--         print $ v
--         print (eye :: Sq 3)
--         print $ ((u & 5) + 1) <·> v
--         print (tm :: L 2 5)
--         print (tm <> sm :: L 2 3)
--         print thingS
--         print thingD
--         print precS
--         print precD
--         print $ withVector (LA.vector [1..15]) sumV
--         splittest

--     sumV w = w <·> konst 1

--     u = vec2 3 5

--     𝕧 x = vector [x] :: R 1

--     v = 𝕧 2 & 4 & 7

--     tm :: GL
--     tm = lmat 0 [1..]

--     lmat :: forall m n . (KnownNat m, KnownNat n) => ℝ -> [ℝ] -> L m n
--     lmat z xs = r
--       where
--         r = mkL . reshape n' . LA.fromList . take (m'*n') $ xs ++ repeat z
--         (m',n') = size r

--     sm :: GSq
--     sm = lmat 0 [1..]

--     thingS = (u & 1) <·> tr q #> q #> v
--       where
--         q = tm :: L 10 3

--     thingD = vjoin [ud1 u, 1] LA.<.> tr m LA.#> m LA.#> ud1 v
--       where
--         m = LA.matrix 3 [1..30]

--     precS = (1::Double) + (2::Double) * ((1 :: R 3) * (u & 6)) <·> konst 2 #> v
--     precD = 1 + 2 * vjoin[ud1 u, 6] LA.<.> LA.konst 2 (LA.size (ud1 u) +1, LA.size (ud1 v)) LA.#> ud1 v


-- splittest
--     = do
--     let v = range :: R 7
--         a = snd (split v) :: R 4
--     print $ a
--     print $ snd . headTail . snd . headTail $ v
--     print $ first (vec3 1 2 3)
--     print $ second (vec3 1 2 3)
--     print $ third (vec3 1 2 3)
--     print $ (snd $ splitRows eye :: L 4 6)
--  where
--     first v = fst . headTail $ v
--     second v = first . snd . headTail $ v
--     third v = first . snd . headTail . snd . headTail $ v
