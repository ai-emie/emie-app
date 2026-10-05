import unittest
from ios_build_config import prepare

class IOSBuildConfigTests(unittest.TestCase):
    def test_local_keeps_existing_entries_and_limits_ats(self):
        base={'CFBundleURLTypes':[{'CFBundleURLSchemes':['existing-plugin']}],
              'NSAppTransportSecurity':{'NSExceptionDomains':{'existing.example':{}}}}
        result=prepare(base,local_port=8010)
        self.assertEqual(result['CFBundleURLTypes'][0],base['CFBundleURLTypes'][0])
        self.assertTrue(result['NSAppTransportSecurity']['NSAllowsLocalNetworking'])
        self.assertNotIn('NSAllowsArbitraryLoads',result['NSAppTransportSecurity'])
        self.assertNotIn('EMIELocalPort',base)
    def test_wrong_ports_and_broad_ats_are_rejected(self):
        for port in [8000,8020]:
            with self.assertRaises(ValueError):prepare({},local_port=port)
        with self.assertRaises(ValueError):prepare({'NSAppTransportSecurity':{'NSAllowsArbitraryLoads':True}},local_port=8010)
    def test_release_needs_confirmed_bundle_and_matching_scheme(self):
        config={'bundle_id':'ai.emiso.emie','ios_client_id':'synthetic-ios.apps.googleusercontent.com',
                'server_client_id':'synthetic-server.apps.googleusercontent.com',
                'reversed_client_id':'com.googleusercontent.apps.synthetic-ios',
                'recovery_origin':'https://synthetic.example.invalid'}
        result=prepare({},release=config)
        self.assertNotIn('NSAppTransportSecurity',result)
        self.assertNotIn('EMIELocalPort',result)
        for bad in [dict(config,bundle_id='wrong'),dict(config,reversed_client_id='wrong'),
                    dict(config,recovery_origin='https://user@synthetic.example.invalid'),
                    dict(config,recovery_origin='http://synthetic.example.invalid')]:
            with self.assertRaises(ValueError):prepare({},release=bad)
    def test_no_implicit_configuration(self):
        with self.assertRaises(ValueError):prepare({})
        with self.assertRaises(ValueError):prepare({},local_port=8010,release={})

if __name__=='__main__':unittest.main(verbosity=2)
