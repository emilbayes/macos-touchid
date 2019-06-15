{
  'targets': [
    {
      'target_name': 'macos_touchid',
      'include_dirs' : [
        '<!(node -e \"require(\'napi-macros\')\")',
      ],
      'sources': [
        'index.m'
      ],
      'xcode_settings': {
        'OTHER_LDFLAGS': [
            '-framework CoreFoundation',
            '-framework LocalAuthentication'
        ],
        'OTHER_CFLAGS': [
          '-g',
          '-O3'
        ]
      },
      'cflags': [
        '-g',
        '-O3'
      ]
    }
  ]
}
