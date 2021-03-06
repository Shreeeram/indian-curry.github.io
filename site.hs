--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad           ( (>=>)      )
import           Data.List               ( isSuffixOf )
import           Data.Monoid             ( mappend, (<>))
import           System.FilePath
import           Hakyll


config :: Configuration
config = defaultConfiguration { deployCommand = "./scripts/deploy.sh" }

--------------------------------------------------------------------------------
main :: IO ()
main = hakyllWith config $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.rst", "contact.markdown"]) $ do
        route   $ cleanRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= fixUrls

    match "posts/*" $ do
        route $ cleanRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= fixUrls

    match "archive/index.md" $ do
        route $ setExtension "html"
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate archiveCtx
                >>= renderPandoc
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= fixUrls

    match "index.md" $ do
        route $ setExtension ".html"
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts)
                    <> constField "title" ""
                    <> defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= renderPandoc
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= fixUrls

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y"
    <> dateField "month" "%b"
    <> dateField "year"  "%Y"
    <> dateField "day"   "%a"
    <> dateField "dayofmonth" "%e"
    <> teaserField "teaser" "content"
    <> defaultContext

------------------------- Cleaning routes --------------------------------------

cleanRoute :: Routes
cleanRoute = customRoute createIndexRoute
  where
    createIndexRoute ident = takeDirectory p </> takeBaseName p </> "index.html"
                            where p = toFilePath ident

cleanIndexUrls :: Item String -> Compiler (Item String)
cleanIndexUrls = return . fmap (withUrls cleanIndex)

cleanIndexHtmls :: Item String -> Compiler (Item String)
cleanIndexHtmls = return . fmap (replaceAll pattern replacement)
    where
      pattern = "/index.html"
      replacement = const "/"

cleanIndex :: String -> String
cleanIndex url
    | idx `isSuffixOf` url = take (length url - length idx) url
    | otherwise            = url
  where idx = "index.html"

fixUrls :: Item String -> Compiler (Item String)
fixUrls = relativizeUrls >=> cleanIndexUrls

