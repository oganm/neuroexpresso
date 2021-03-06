
print('starting server')




# beginning of server -----------
shinyServer(function(input, output, session) {
    
    lb = linked_brush2(keys = NULL, "red")
    
    vals =  reactiveValues(fingerprint = '', # will become user's fingerprint hash
                           ipid = '',  # will become user's ip address
                           searchedGenes = 'Ogn Cortex GPL339', # a history of searched genes to be saved
                           gene = 'Ogn',
                           region = 'Cortex',
                           platform = 'GPL339',
                           treeChoice = NULL,
                           treeSelected = list(),
                           new = TRUE, # did the app just start?
                           querry = 'NULL', # will become the querry string if something is being querried
                           hierarchies=NULL, # which hierarchy is selected
                           hierarchInit = NULL, # will be set to the initial hierarchy
                           difGroup1= NULL,
                           difGroup2 = NULL,
                           differentiallyExpressed = NULL,
                           staticTreeInit = FALSE)
    hide(id="group2Selected")
    hide(id = 'newSelection')
    hide(id = 'downloadDifGenes')
    hide(id = 'difGenePanel')
    
    observe({
        if(input$tabs=='genes'){
            shinyjs::hide(id = 'difPlot-container')
            shinyjs::show(id = 'expressionPlot-container')
            shinyjs::enable(selector = "input[value = 'Fixed Y axis']")
        } else if(input$tabs == 'difExp'){
            shinyjs::hide(id = 'expressionPlot-container')
            shinyjs::show(id = 'difPlot-container')
            shinyjs::disable(selector = "input[value = 'Fixed Y axis']")
        }
    })
    
    # querry parsing ------
    observe({
        vals$querry = parseQueryString(session$clientData$url_search)
        print(vals$querry)
    })
    
    # this shouldn't be necesarry but first plot does not show the axis labels for no real reason.
    observe({
        if(vals$new & is.null(vals$querry$gene)){
            # this replaces the initial configuration of the textInput so that the plot will be drawn twice
            # this shouldn't be necesarry, alas it seems to be...
            
            updateTextInput(session,
                            inputId = 'searchGenes', value= 'Ogn',
                            label = 'Select Gene')
            
            
            vals$new= FALSE
        } else if (vals$new & !is.null(vals$querry$gene)){
            # browser()
            updateTextInput(session,
                            inputId = 'searchGenes',
                            value = vals$querry$gene,
                            label = 'Select Gene')
            
            vals$new= FALSE
        }
        
    })
    
    observe({
        if (!is.null(vals$querry$region)){
            # browser()
            regQuerry  = names(regionGroups$GPL339)[tolower(names(regionGroups$GPL339)) %in% tolower(vals$querry$region)]
            
            updateSelectInput(session,
                              inputId = "regionChoice",
                              label= 'Select region',
                              selected = regQuerry,
                              choices = names(regionGroups$GPL339))
            
            # #planned feature
            # selected = nametreeVector(regionHierarchy)[
            #     str_extract(regionHierarchy %>% nametreeVector,'([A-Z]|[a-z])*?(?=\n)') %in% regQuerry
            #     ],
            # choices = regionHierarchy %>% nametreeVector)
        }
    })
    
    observe({
        if (!is.null(vals$querry$platform)){
            # browser()
            regQuerry  = names(exprs)[tolower(names(exprs)) %in% tolower(vals$querry$platform)]
            
            updateSelectInput(session,
                              inputId = "platform",
                              label= 'Select Platform',
                              selected = regQuerry,
                              choices =  names(exprs))
        }
    })
    
    
    # check validity of input -----------
    observe({
        #browser()
        selected  =  genes[[input$platform]]$Gene.Symbol[tolower(genes[[input$platform]]$Gene.Symbol) %in% tolower(input$searchGenes)]
        
        if (len(selected)>0){
            vals$searchedGenes <- c(isolate(vals$searchedGenes), paste(selected,input$regionChoice,input$platform))
            vals$gene = strsplit(vals$searchedGenes[len(vals$searchedGenes)],' ')[[1]][1]
            vals$region = strsplit(vals$searchedGenes[len(vals$searchedGenes)],' ')[[1]][2]
            vals$platform = strsplit(vals$searchedGenes[len(vals$searchedGenes)],' ')[[1]][3]
            print(vals$searchedGenes)
        }
    })
    
    # validity of trees
    observe({
        treeSelected = get_selected(input$tree)
        treeChoice =  input$treeChoice
        
        validTree = hierarchies %>% sapply(function(x){
            hiearNames = x %>% unlist %>% names %>% strsplit('\\.(?![ ,])',perl=TRUE) %>% unlist %>% unique
            all(treeSelected %in% hiearNames) | length(treeSelected)==0
        })
        
        if(!is.null(treeChoice)){
            if(validTree[treeChoice]){
                vals$treeSelected = treeSelected
                vals$treeChoice =  treeChoice
            }
        }
        # vals$treeSelected = treeSelected
        # vals$treeChoice =  treeChoice
    })
    
    # create frame as a reactive object to pass to ggvis --------------------
    frame = reactive({
        selected = vals$gene
        region =  vals$region
        platform = vals$platform
        
        geneList = genes[[platform]]
        expression = exprs[[platform]]
        design = designs[[platform]]
        regionSelect = regionGroups[[platform]][[region]]
        # browser()
        frame = createFrame(selected,
                            geneList,
                            expression,
                            design,
                            prop,
                            'Reference',
                            "PMID",
                            coloring,
                            'Gene.Symbol', 
                            regionSelect,
                            'Color' %in% input$graphSettings,
                            input$ordering,
                            vals$treeChoice, vals$treeSelected)
        # display = input$display %>% replaceElement(c(Microarray=FALSE,RNAseq = TRUE)) %$% newVector
        frame %<>% filter( rnaSeq %in% input$display & !is.na(gene))
        
        # oldFrame <<- frame
        lb$set_keys(1:nrow(frame))
        
        # this has to be unique because of gviss' key requirement and has to be ordered 
        if(nrow(frame)>0){
            frame$id = 1:nrow(frame)
        } else{
            frame$id = integer(0)
        }

        delay(100,{
            js$hidePlotTooltip()
        })
        return(frame)
    })
    
    output$geneFound = renderText({
        if(length(vals$gene)>0){
            platform = vals$platform
            geneList = genes[[platform]]
            geneToPlot = geneList %>% filter(Gene.Symbol == vals$gene)
            if(!is.null(geneToPlot$GeneNames)){
                out = glue('Plotting {vals$gene} ({geneToPlot$GeneNames})')
            } else{
                # if RNA seq get imaginative
                # there are few genes that are in GPL339 but not in GPL1261 
                # so look in both
                gTPGPL339 = genes$GPL339 %>% filter(Gene.Symbol == vals$gene)
                gTPGPL1261 = genes$GPL1261 %>% filter(Gene.Symbol == vals$gene)
                if(nrow(gTPGPL339)!=1 & nrow(gTPGPL1261!=1)){
                    out = glue('Plotting {vals$gene}')
                } else if(nrow(gTPGPL1261==1)){
                    out = glue('Plotting {vals$gene} ({gTPGPL1261$GeneNames})')
                } else if(nrow(gTPGPL339==1)){
                    out = glue('Plotting {vals$gene} ({gTPGPL339$GeneNames})')
                }
                
            }
            return(out)
        }
    })
    
    # differential expression -----------------
    observe({
        print(input$group1Selected)
        isolate({
            if(input$group1Selected>=1){
                if(!any(lb$selected())){
                    selected = TRUE
                } else {
                    selected = lb$selected()
                }
                print('save 1')
                shinyjs::hide(id = 'group1Selected')
                shinyjs::show(id = 'group2Selected')
                vals$difGroup1 = frame()[selected,]$GSM
                print(vals$difGroup1)
            }
        })
    })
    
    observe({
        print(input$group2Selected)
        isolate({
            # browser()
            if(input$group2Selected>=1){
                if(!any(lb$selected())){
                    selected = TRUE
                } else {
                    selected = lb$selected()
                }
                print('save 2')
                hide(id = 'group2Selected')
                shinyjs::show(id = 'newSelection')
                shinyjs::show(id = 'downloadDifGenes')
                vals$difGroup2 = frame()[selected,]$GSM
                print(vals$difGroup2)
                
                whichDif = exprs %>% sapply(function(x){
                    all(c(vals$difGroup1,vals$difGroup2) %in% colnames(x))
                })
                
                toDif = exprs[whichDif] %>% sapply(nrow) %>% which.max %>% names %>% {exprs[[.]][c(vals$difGroup1,vals$difGroup2)]}
                
                mm = model.matrix(~ groups,
                                  data.frame(groups = c(rep('a',length(vals$difGroup1)),
                                                        rep('b',length(vals$difGroup2)))))
                
                fit <- limma::lmFit(toDif, mm)
                fit <- limma::eBayes(fit)
                dif = limma::topTable(fit, coef=colnames(fit$design)[2],
                                      number = Inf)
                vals$differentiallyExpressed = data.frame(Symbol = rownames(dif),dif)
                
                shinyjs::show('difGenePanel')
            }
        })
    })
    output$difGeneTable = renderDataTable({
        if(!is.null(vals$differentiallyExpressed)){
            vals$differentiallyExpressed %<>% 
                mutate(logFC =  round(logFC, digits=3),
                       AveExpr =  round(AveExpr, digits=3),
                       t =  round(t, digits=3),
                       P.Value =  round(P.Value, digits=3),
                       adj.P.Val =  round(adj.P.Val, digits=3),
                       B =  round(B, digits=3))
            datatable(vals$differentiallyExpressed,selection = 'single')
        }
    })
    
    
    # replace the selected gene with the one selected from the table
    observe({
        input$difGeneTable_rows_selected
        isolate({
            if(!is.null(input$difGeneTable_rows_selected)){
                tableGene = vals$differentiallyExpressed[input$difGeneTable_rows_selected,'Symbol']
                updateTextInput(session, 'searchGenes','Select Gene', value= tableGene)
            }
        })
    })
    
    output$downloadDifGenes = downloadHandler(
        filename = 'difGenes.tsv',
        content = function(file) {
            write_tsv(vals$differentiallyExpressed, file)
        })
    
    observe({
        print(input$newSelection)
        isolate({
            if(input$newSelection>=1){
                print('new selection')
                hide(id = 'newSelection')
                hide(id = 'downloadDifGenes')
                hide(id = 'difGenePanel')
                shinyjs::show(id = 'group1Selected')
                print(lb$selected())
            }
        })
    })
    
    
    frame %>%  #hede %>%
        ggvis(~prop,~gene,fill := ~color,shape = ~`Data Source` ,
              key := ~id,size :=140 ,
              stroke := 'black',
              opacity := 0.7,
              size.brush := 300) %>%
        layer_points() %>% 
        scale_nominal('shape',c('Microarray', 'RNAseq')) %>% 
        lb$input() %>%
        set_options(height = 700, width = 750) %>%
        add_axis('x',
                 #shame shame shame! but its mostly ggvis' fault
                 title=' ',
                 properties = axis_props(labels = list(angle=45,
                                                       align='left',
                                                       fontSize = 20)),
                 title_offset = 150) %>%
        add_axis('y',
                 title = 'log2 expression',
                 properties = axis_props(title = list(fontSize = 17),
                                         labels = list(fontSize =14)),
                 title_offset = 50) %>%
        bind_shiny('difPlot')
    
    # main plot -----------------
    # the plot has to be reactively created for its title to be prone to changes. anything that is not part of the frame
    # has to be passed inside this reactive block and will cause plot to be refreshed.
    reactive({
        gene = vals$gene
        p = frame %>%
            ggvis(~prop,~gene,fill := ~color,key := ~id,shape = ~`Data Source` ,size :=140, stroke := 'black', opacity := 0.7) %>%
            scale_nominal('shape',c('Microarray', 'RNAseq')) %>% 
            layer_points() %>%
            add_tooltip(function(x){
                # get links to GSM
                if(is.na(frame()$rnaSeq[x$id])){
                    return('')
                }
                if (frame()$rnaSeq[x$id] == 'RNAseq'){
                    src = glue("<p><a target='_blank' href='https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE71585'>{frame()$GSM[x$id]}</a></p>",
                               "<p><a target='_blank' href='http://casestudies.brain-map.org/celltax#section_explorea'>Allen Atlas Vis App</a></p>")
                } else if(!grepl('GSM',frame()$GSM[x$id])){
                    src = paste0('<p>Contact authors</p>',frame()$GSM[x$id])
                } else {
                    src = paste0("<p><a target='_blank' href=",
                                 "'http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=",
                                 frame()$GSM[x$id],
                                 "'>",
                                 frame()$GSM[x$id],
                                 '</a></p>')
                }
                print(src)
                
                # get link to pubmed
                if(is.na(frame()$PMID[x$id])){
                    paper = paste0('<p>',as.character(frame()[x$id,]$reference),'</p>')
                } else {
                    paper = paste0("<p><a target='_blank' href=",
                                   "'http://www.ncbi.nlm.nih.gov/pubmed/",
                                   frame()$PMID[x$id],"'>",
                                   as.character(frame()[x$id,]$reference),
                                   '</a></p>')
                }
                
                print(paper)
                
                return(paste0(paper,src))
            }, on = 'click') %>% 
            add_axis('y',
                     title = paste(gene,"log2 expression"),
                     properties = axis_props(title = list(fontSize = 17),
                                             labels = list(fontSize =14)),
                     title_offset = 50) %>%
            add_axis('x',title='', properties = axis_props(labels = list(angle=45,
                                                                         align='left',
                                                                         fontSize = 20))) %>%
            set_options(height = 700, width = 750)
        if('Fixed Y axis' %in% input$graphSettings){
            p = p %>% scale_numeric('y',domain = c(minValue,maxValue))
        }
        return(p)
    }) %>%  bind_shiny('expressionPlot')
    
    # did you mean?--------
    output$didYouMean = renderUI({
        if(any(tolower(genes[[input$platform]]$Gene.Symbol) %in% tolower(input$searchGenes))){
            return('')
        } else{
            symbolList = genes[[input$platform]]$Gene.Symbol
            
            inPlatforms = names(genes) %>% sapply(function(x){
                tolower(input$searchGenes) %in% tolower(genes[[x]]$Gene.Symbol)
            })
            
            if(sum(inPlatforms)>0){
                inPlatforms = names(inPlatforms[inPlatforms])
                if(length(inPlatforms)>1){
                    s= 's'
                } else{
                    s =''
                }
                inPlatforms = glue('Available in {paste(inPlatforms,collapse=", ")} platform{s}')
            } else{
                inPlatforms = ''
            }
            
            didYouMean = paste('Did you mean:\n',paste(symbolList[order(adist(tolower(input$searchGenes), 
                                                                              tolower(symbolList)))[1:5]],
                                                       collapse=', '))
            
            return(HTML(paste0(inPlatforms,'<br/>',didYouMean)))
        }
    })
    
    # find if entered gene is a synonym of something else -------
    output$synonyms = renderText({
        synos = mouseSyno(input$searchGenes,caseSensitive= FALSE)[[1]]
        synos = sapply(synos, function(x){
            if(!tolower(x[1]) == tolower(input$searchGenes)){
                return(x[1])
            } else{
                return(NULL)
            }
        }
        ) %>% unlist
        
        if(len(synos) > 0 ){
            return(paste('Synonym of:', paste(synos,collapse=',')))
        } else{
            return('')
        }
    })
    # is a marker? ----------
    output$tisAMarker = renderUI({
        markerOf = names(mouseMarkerGenesCombined) %>% lapply(function(x){
            index = findInList(input$searchGenes,mouseMarkerGenesCombined[[x]])
            names(mouseMarkerGenesCombined[[x]])[index]
        })
        names(markerOf) = names(mouseMarkerGenesCombined) 
        types = unique(unlist(markerOf))
        types %>% sapply(function(x){
            paste('Identified as marker of',x,'in',
                  paste(names(markerOf)[findInList(x,markerOf)] ,collapse = ', '))
        }) -> out
        
        if(length(out)==0){
            out =p('Not identified as a marker')
        } else{
            out = div(out %>% lapply(p))
        }
        return(out)
    })
    
    # allen institute ----------
    output$allenBrain = renderUI({
        gene = tolower(input$searchGenes)
        allenGenes = tolower(names(allenIDs))
        if(gene %in% allenGenes){
            whichMatch = which(allenGenes %in% gene)
            link = paste0('http://mouse.brain-map.org/experiment/ivt?id=',paste(allenIDs[[whichMatch]],collapse=','),'&popup=true')
            out = p(names(allenIDs)[whichMatch],' on ',
                    a(href=link,target= '_blank', 'Allen Institute ISH data'))
        } else{
            out = p('Not found in Allen Institute Mouse ISH data')
        }
        return(out)
    })
    
    
    # hiearchy stuff ------------------
    observe({
        # print(get_selected(input$tree))
        region = 'Cortex'
        if (!is.null(vals$querry$region)){
            region = names(regionGroups$GPL339)[tolower(names(regionGroups$GPL339)) %in% tolower(vals$querry$region)]
        }
        levels = hierarchyNames[[1]]
        vals$hierarchInit = hierarchize(levels, designs$GPL339[!is.na(designs$GPL339[,levels[len(levels)]]) & !is.na(regionGroups$GPL339[[region]]),])
    })
    
    # generate new hierarchies every time region changes
    observe({
        # browser()
        vals$hierarchies = lapply(hierarchyNames, function(levels){
            hierarchize(levels,designs[[vals$platform]][!is.na(designs[[vals$platform]][,levels[len(levels)]]) & !is.na(regionGroups[[vals$platform]][[vals$region]]),])
        })
    })

    
    observe({
        if (!is.null(input$treeChoice)){
            jsInput = toTreeJSON(vals$hierarchies[[input$treeChoice]])
            js$changeTree(jsInput) 
            delay(100,{
                js$open()
                js$deselect()
            })
        }
    })
    
    
    # choice of tree
    output$selectTree = renderUI({
        #browser()
        selectInput(inputId = "treeChoice",
                    label= 'Select hierarchy',
                    selected = names(hierarchyNames)[1],
                    choices = names(hierarchyNames))
    })
    
    
    output$tree = renderTree({
        # browser()
        js$setDefaultTree()
        #vals$hierarchies[[input$treeChoice]]
        vals$hierarchInit
    })
    
    observe({
        if (vals$staticTreeInit){
            # browser()
            # jsInput = toTreeJSON(regionHierarchy)
            # js$setStaticTree(jsInput) 
            delay(500,{
                js$openStaticTree()
            })
        }
    })
    
    output$staticRegionTree = renderTree({
        vals$staticTreeInit = TRUE
        regionHierarchy  
    })
    
})
