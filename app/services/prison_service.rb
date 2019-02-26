class PrisonService
  PRISONS = {
    'ACI' => 'HMP Altcourse',
    'AGI' => 'HMP/YOI Askham Grange',
    'ALI' => 'HMP Albany',
    'ASI' => 'HMP Ashfield',
    'AYI' => 'HMP Aylesbury',
    'BAI' => 'HMP Belmarsh',
    'BCI' => 'HMP Buckley Hall',
    'BFI' => 'HMP Bedford',
    'BHI' => 'HMP Blantyre House',
    'BLI' => 'HMP Bristol',
    'BMI' => 'HMP Birmingham',
    'BNI' => 'HMP Bullingdon',
    'BRI' => 'HMP Bure',
    'BSI' => 'HMP Brinsford',
    'BWI' => 'HMP Berwyn',
    'BXI' => 'HMP Brixton',
    'BZI' => 'HMP Bronzefield',
    'CDI' => 'HMP Chelmsford',
    'CFI' => 'HMP Cardiff',
    'CKI' => 'HMP Cookham Wood',
    'CLI' => 'HMP Coldingley',
    'CWI' => 'HMP Channings Wood',
    'DAI' => 'HMP Dartmoor',
    'DGI' => 'HMP Dovegate',
    'DHI' => 'HMP/YOI Drake Hall',
    'DMI' => 'HMP Durham',
    'DNI' => 'HMP Doncaster',
    'DTI' => 'HMP/YOI Deerbolt',
    'DWI' => 'HMP Downview',
    'EEI' => 'HMP Erlestoke',
    'EHI' => 'HMP Standford Hill',
    'ESI' => 'HMP/YOI East Sutton Park',
    'EWI' => 'HMP Eastwood Park',
    'EXI' => 'HMP Exeter',
    'EYI' => 'HMP Elmley',
    'FBI' => 'HMP/YOI Forest Bank',
    'FDI' => 'HMP Ford',
    'FHI' => 'HMP Foston Hall',
    'FKI' => 'HMP Frankland',
    'FMI' => 'HMP/YOI Feltham',
    'FNI' => 'HMP Full Sutton',
    'FSI' => 'HMP Featherstone',
    'GHI' => 'HMP Garth',
    'GMI' => 'HMP Guys Marsh',
    'GNI' => 'HMP Grendon',
    'GPI' => 'HMP/YOI Glen Parva',
    'GTI' => 'HMP Gartree',
    'HBI' => 'HMP Hollesley Bay',
    'HCI' => 'HMP Huntercombe',
    'HDI' => 'HMP/YOI Hatfield',
    'HHI' => 'HMP Holme House',
    'HII' => 'HMP/YOI Hindley',
    'HLI' => 'HMP Hull',
    'HMI' => 'HMP Humber',
    'HOI' => 'HMP High Down',
    'HPI' => 'HMP Highpoint',
    'HVI' => 'HMP Haverigg',
    'IWI' => 'HMP Isle Of Wight',
    'KMI' => 'HMP Kirkham',
    'KTI' => 'HMP Kennet',
    'KVI' => 'HMP Kirklevington Grange',
    'LCI' => 'HMP Leicester',
    'LEI' => 'HMP Leeds',
    'LFI' => 'HMP/YOI Lancaster Farms',
    'LGI' => 'HMP Lowdham Grange',
    'LHI' => 'HMP Lindholme',
    'LII' => 'HMP Lincoln',
    'LLI' => 'HMP Long Lartin',
    'LNI' => 'HMP Low Newton',
    'LPI' => 'HMP Liverpool',
    'LTI' => 'HMP Littlehey',
    'LWI' => 'HMP Lewes',
    'LYI' => 'HMP Leyhill',
    'MDI' => 'HMP/YOI Moorland',
    'MRI' => 'HMP Manchester',
    'MSI' => 'HMP Maidstone',
    'MTI' => 'HMP The Mount',
    'MWI' => 'HMP Medway',
    'NHI' => 'HMP New Hall',
    'NLI' => 'HMP Northumberland',
    'NMI' => 'HMP Nottingham',
    'NSI' => 'HMP North Sea Camp',
    'NWI' => 'HMP/YOI Norwich',
    'ONI' => 'HMP Onley',
    'OWI' => 'HMP Oakwood',
    'PBI' => 'HMP Peterborough',
    'PDI' => 'HMP/YOI Portland',
    'PNI' => 'HMP Preston',
    'PRI' => 'HMP Parc',
    'PVI' => 'HMP Pentonville',
    'RCI' => 'HMP/YOI Rochester',
    'RHI' => 'HMP Rye Hill',
    'RNI' => 'HMP Ranby',
    'RSI' => 'HMP Risley',
    'SDI' => 'HMP Send',
    'SFI' => 'HMP Stafford',
    'SHI' => 'HMP/YOI Stoke Heath',
    'SKI' => 'HMP Stocken',
    'SLI' => 'HMP Swaleside',
    'SNI' => 'HMP Swinfen Hall',
    'SPI' => 'HMP Spring Hill',
    'STI' => 'HMP/YOI Styal',
    'SUI' => 'HMP/YOI Sudbury',
    'SWI' => 'HMP Swansea',
    'TCI' => 'HMP/YOI Thorn Cross',
    'TSI' => 'HMP Thameside',
    'UKI' => 'HMP Usk',
    'UPI' => 'HMP/YOI Prescoed',
    'WCI' => 'HMP Winchester',
    'WDI' => 'HMP Wakefield',
    'WEI' => 'HMP Wealstun',
    'WHI' => 'HMP Woodhill',
    'WII' => 'HMP Warren Hill',
    'WLI' => 'HMP Wayland',
    'WMI' => 'HMP Wymott',
    'WNI' => 'HMP/YOI Werrington',
    'WRI' => 'HMP Whitemoor',
    'WSI' => 'HMP Wormwood Scrubs',
    'WTI' => 'HMP Whatton',
    'WWI' => 'HMP Wandsworth',
    'WYI' => 'HMP/YOI Wetherby'
  }

  def self.name_for(code)
    PRISONS[code]
  end
end
