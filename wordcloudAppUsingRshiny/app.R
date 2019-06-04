library(shiny)
library(colourpicker)
library(tm)
library(qdap)
library(tidyverse)
library(RWeka)
library(wordcloud2)

amzn <- read.csv("500_amzn.csv", stringsAsFactors = FALSE)
amzn_pros <- amzn$pros

qdap_clean <- function(x) {
  x <- replace_abbreviation(x)
  x <- replace_contraction(x)
  x <- replace_number(x)
  x <- replace_ordinal(x)
  x <- replace_symbol(x)
  x <- tolower(x)
  return(x)
}

# tm cleaning function
tm_clean <- function(corpus) {
  tm_clean <- tm_map(corpus, removePunctuation)
  corpus <- tm_map(corpus, stripWhitespace)
  corpus <- tm_map(corpus, removeWords,
                   c(stopwords("en"), "Google", "Amazon", "company"))
  return(corpus)
}

tokenizer <- function(x, gram=2) {
  NGramTokenizer(x, Weka_control(min = gram, max = gram))
}

create_wordcloud <- function(data, 
                             num_words = 100, 
                             background = "white"){
  
  qdap_cleaned_amzn_pros <- qdap_clean(data)
  
  qdap_cleaned_amzn_pros[which(is.na(qdap_cleaned_amzn_pros))] <- "NULLVALUE"
  # Source and create the corpus
  amzn_p_corp <- VCorpus(VectorSource(qdap_cleaned_amzn_pros))
  
  # tm_clean the corpus
  amzn_pros_corp <- tm_clean(amzn_p_corp)
  
  
  amzn_p_tdm <- TermDocumentMatrix(amzn_pros_corp, 
                                   control = list(tokenize = tokenizer))
  
  # Create amzn_p_tdm_m
  amzn_p_tdm_m <- as.matrix(amzn_p_tdm)
  
  # Create amzn_p_freq
  amzn_p_freq <- rowSums(amzn_p_tdm_m)
  
  v <- sort(amzn_p_freq,decreasing=TRUE)
  
  d <- data.frame(word = names(v),freq=v)
  d <- d %>% slice(1:num_words)
  wordcloud2(d, backgroundColor = background)
  
}

ui <- fluidPage(
  h1("Word Cloud"),
  sidebarLayout(
    sidebarPanel(
      radioButtons(
        inputId = "source",
        label = "Word source",
        choices = c(
          "Positive reviews for jobs at Amazon" = "book",
          "Use your own words" = "own",
          "Upload a file" = "file"
        )
      ),
      conditionalPanel(
        condition = "input.source == 'own'",
        textAreaInput("text", "Enter text", rows = 7)
      ),
      conditionalPanel(
        condition = "input.source == 'file'",
        fileInput("file", "Select a file")
      ),
      numericInput("num", "Maximum number of words",
                   value = 100, min = 5),
      colourInput("col", "Background colour", value = "white"),
      # Add a "draw" button to the app
      actionButton(inputId = 'draw', label = 'Draw!')
    ),
    mainPanel(
      wordcloud2Output("cloud")
    )
  )
)

server <- function(input, output) {
  data_source <- reactive({
    if (input$source == "book") {
      data <- amzn_pros
    } else if (input$source == "own") {
      data <- input$text
    } else if (input$source == "file") {
      data <- input_file()
    }
    return(data)
  })
  
  input_file <- reactive({
    if (is.null(input$file)) {
      return("")
    }
    readLines(input$file$datapath)
  })
  
  output$cloud <- renderWordcloud2({
    # Add the draw button as a dependency to
    # cause the word cloud to re-render on click
    input$draw
    isolate({
      create_wordcloud(data_source(), num_words = input$num,
                       background = input$col)
    })
  })
}

shinyApp(ui = ui, server = server)