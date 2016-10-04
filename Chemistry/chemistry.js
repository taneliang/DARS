{
	"greetings":
	{
		"default_keyword": "greetings.generic",
		"tokens":
		[
		 {"token": "hi"},
		 {"token": "hey"},
		 {"token": "howdy"},
		 {"token": "hello"},
		 {"token": "greetings"},
		 {"token": "good morning", "keyword": "greetings.timebased.morning"},
		 {"token": "good afternoon", "keyword": "greetings.timebased.afternoon"},
		 {"token": "good evening", "keyword": "greetings.timebased.evening"},
		 {"token": "good night", "keyword": "greetings.timebased.night"},
		 {"token": "good bye", "keyword": "greetings.generic.reverse"},
		 {"token": "bye", "keyword": "greetings.generic.reverse"},
		 {"token": "farewell", "keyword": "greetings.generic.reverse"},
		 ],
	},
	"address":
	{
		"default_keyword": "address.computer",
		"tokens":
		[
		 {"token": "you"},
		 {"token": "you piece of shit"},
		 {"token": "my friend"},
		 {"token": "computer"},
		 {"token": "komputer"},
		 {"token": "sir"},
		 {"token": "all-knowing machine"}
		 ],
	},
	"preprerequestpadding":
	{
		"default_keyword": "preprerequestpadding.generic",
		"tokens":
		[
		 {"token": "please"},
		 {"token": "could you"}
		 ],
	},
	"query_type":
	{
		"default_keyword": "query_type.definition",
		"tokens":
		[
		 {"token": "what's"},
		 {"token": "what is"},
		 {"token": "which"},
		 {"token": "tell me"},
		 {"token": "give me"},
		 {"token": "may I have"},
		 {"token": "spit out"},
		 {"token": "hand over"},
		 {"token": "how many", "keyword": "query_type.quantity"},
		 {"token": "the number of", "keyword": "query_type.quantity"},
		 {"token": "when", "keyword": "query_type.when"},
		 {"token": "at what time", "keyword": "query_type.when"},
		 {"token": "who", "keyword": "query_type.who"},
		 {"token": "where", "keyword": "query_type.location"},
		 {"token": "why", "keyword": "query_type.cause"},
		 {"token": "how", "keyword": "query_type.courseofaction"},
		 ],
	},
	"request_descriptor":
	{
		"default_keyword": "request_descriptor.undefined",
		"tokens":
		[
		 {"token": "in", "keyword": "request_descriptor.thingsin"},
		 {"token": "details of", "keyword": "request_descriptor.detailsof"},
		 {"token": "information regarding", "keyword": "request_descriptor.detailsof"},
		 {"token": "details regarding", "keyword": "request_descriptor.detailsof"},
		 {"token": "name of", "keyword": "request_descriptor.nameof"},
		 {"token": "chemical symbol of", "keyword": "request_descriptor.chemicalsymbolof"},
		 {"token": "proton number of", "keyword": "request_descriptor.protonnumberof"},
		 {"token": "relative atomic mass of", "keyword": "request_descriptor.relativeatomicmassof"},
		 {"token": "mass of", "keyword": "request_descriptor.massof"}
		 ],
	},
	"request_object":
	{
		"default_keyword": "request_object.undefined",
		"tokens":
		[
		 {"token": "element", "keyword": "request_object.element"},
		 {"token": "periodic table", "keyword": "request_object.periodictable"},
		 ],
	},
	"postrequestpadding":
	{
		"default_keyword": "postrequestpadding.generic",
		"tokens":
		[
		 {"token": "thank you"},
		 {"token": "thanks"},
		 {"token": "your assistance is greatly appreciated"},
		 ],
	}
}