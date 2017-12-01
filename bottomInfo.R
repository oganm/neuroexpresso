bottomInfo = function(){
    wellPanel(
        h3('NeuroExpresso data and marker genes'),
        p('The data in NeuroExpresso compiled as part of a project aiming to select marker genes for brain cell types
                               and calculate marker gene profiles.'),
        p('The data in neuroexpresso and marker genes identified in the study can be accessed ',
          a(href = 'http://pavlab.msl.ubc.ca/supplement-to-mancarci-et-al-neuroexpresso/', 
            target="_blank",'here.')),
        p('R package for calculation of marker gene profiles can be found ',
          a(href='https://github.com/oganm/markerGeneProfile',
            target = '_blank','here.')),
        h3('How to cite'),
        p('If using NeuroExpresso or the data provided, please cite:'),
        a(href = 'http://www.eneuro.org/content/early/2017/11/20/ENEURO.0212-17.2017',
          target="_blank", 
          'B. Ogan Mancarci et al., “Cross-Laboratory Analysis of Brain Cell Type Transcriptomes with Applications to Interpretation of Bulk Tissue Data,” ENeuro, November 20, 2017, ENEURO.0212-17.2017, https://doi.org/10.1523/ENEURO.0212-17.2017.'),
        h3('Contact'),
        p('If you have questions or problems, mail', 
          a(href="mailto:ogan.mancarci@msl.ubc.ca",
            target= '_blank', 'Ogan Mancarci'),
          ". Please mention NeuroExpresso by name to ensure avoiding spam detectors"),
        p('To report bugs, open an issue on the',a(href="https://github.com/oganm/neuroexpresso/issues",target= '_blank', 'github repo'))
    )
}