%%%----------------------------------------------------------------------
%%% File    : xml_gen.hrl
%%% Author  : Evgeniy Khramtsov <ekhramtsov@process-one.net>
%%% Purpose : XML utils
%%% Created : 1 May 2013 by Evgeniy Khramtsov <ekhramtsov@process-one.net>
%%%
%%%
%%% Copyright (C) 2002-2015 ProcessOne, SARL. All Rights Reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%
%%%----------------------------------------------------------------------

-record(attr, {name,
	       label,
	       required = false,
	       default,
	       dec,
	       enc}).

-record(cdata, {required = false,
		label = '$cdata',
		default,
		dec,
		enc}).

-record(elem, {name,
               xmlns = <<"">>,
               cdata = #cdata{},
               result,
               attrs = [],
               refs = []}).

-record(ref, {name,
              label,
              min = 0,
              max = infinity,
              default}).
