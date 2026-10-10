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

    def test_device_exact_host_only_in_explicit_local_plist(self):
        result=prepare({},local_port=8013,local_device=True,local_host='172.20.10.11')
        self.assertEqual(result['EMIELocalHost'],'172.20.10.11')
        self.assertEqual(result['EMIELocalPort'],8013)
        self.assertTrue(result['EMIELocalDevice'])
        self.assertNotIn('NSAllowsLocalNetworking',result['NSAppTransportSecurity'])
        with self.assertRaises(ValueError):prepare(result,local_port=8010)
        with self.assertRaises(ValueError):prepare(result,release={})
        self.assertIn('NSLocalNetworkUsageDescription',result)
        self.assertEqual(result['NSAppTransportSecurity']['NSExceptionDomains'],
                         {'172.20.10.11':{'NSExceptionAllowsInsecureHTTPLoads':True,'NSIncludesSubdomains':False}})
        self.assertNotIn('NSAllowsArbitraryLoads',result['NSAppTransportSecurity'])
        self.assertNotIn('EMIELocalHost',prepare({},local_port=8010))
    def test_device_rejects_implicit_and_public_targets(self):
        for kwargs in [dict(local_host='172.20.10.11'),dict(local_device=True),
                       dict(local_port=8010,local_host='172.20.10.11'),
                       dict(local_port=8010,local_device=True),
                       dict(local_device=True,local_host='172.20.10.11',release={})]:
            with self.assertRaises(ValueError):prepare({},**kwargs)
        for host in ['127.0.0.1','0.0.0.0','8.8.8.8','169.254.2.3','172.32.0.1','localhost',
                     '192.168.001.1','10.0.0.256','https://10.0.0.1','10.0.0.1:8010','user@10.0.0.1','10.0.0.1/24']:
            with self.subTest(host=host),self.assertRaises(ValueError):
                prepare({},local_port=8010,local_device=True,local_host=host)
        for host in ['10.0.0.1','172.16.0.1','172.31.255.254','192.168.1.2']:
            self.assertEqual(prepare({},local_port=8019,local_device=True,local_host=host)['EMIELocalHost'],host)

if __name__=='__main__':unittest.main(verbosity=2)
