@load base/frameworks/notice

module DetectTor;

export {
	redef enum Notice::Type += { 
		## Indicates that a host using Tor was discovered.
		DetectTor::Found 
	};

	## Distinct Tor-like X.509 certificates to see before deciding it's Tor.
	const tor_cert_threshold = 10.0;

	## Time period to see the :bro:see:`tor_cert_threshold` certificates
	## before deciding it's Tor.
	const tor_cert_period = 5min;
}

event bro_init()
	{
	local r1 = SumStats::Reducer($stream="ssl.tor-looking-cert", $apply=set(SumStats::UNIQUE));
	SumStats::create([$name="detect-tor",
	                  $epoch=tor_cert_period,
	                  $reducers=set(r1),
	                  $threshold_val(key: SumStats::Key, result: SumStats::Result) =
	                  	{
	                  	return result["ssl.tor-looking-cert"]$unique+0.0;
	                  	},
	                  $threshold=tor_cert_threshold,
	                  $threshold_crossed(key: SumStats::Key, result: SumStats::Result) =
	                  	{
	                  	local r = result["ssl.tor-looking-cert"];
	                  	NOTICE([$note=DetectTor::Found,
	                  	        $msg=fmt("%s was found using Tor by connecting to servers with at least %d unique weird certs", key$host, r$unique),
	                  	        $src=key$host,
	                  	        $identifier=cat(key$host)]);
	                  	}]);
	}

event x509_certificate(c: connection , is_orig: bool , cert: X509 , chain_idx: count , chain_len: count , der_cert: string )
	{
	if ( /^CN=[^=,]*$/ == cert$subject && /^CN=[^=,]*$/ == cert$issuer )
		{
		SumStats::observe("ssl.tor-looking-cert", [$host=c$id$orig_h], [$str=cert$subject]);
		}
	}