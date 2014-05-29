require './rest'

require 'base64'

user = "***REMOVED***"
pass = "***REMOVED***"

url = "http://localhost:9000/v1/cap/transaction/certificate_ready"
# payload = JSON.parse('{"first_name" : "Andrés", "last_name" : "Colón",
#             "mother_last_name" : "Pérez", "ssn" : "111-22-3333",
#             "license" : "12345678", "birth_date" : "01/01/1982",
#             "residency" : "San Juan", "IP" : "192.168.1.2",
#             "reason" : "Solicitud de Empleo", "birth_place" : "San Juan",
#             "email" : "acolon@ogp.pr.gov", "license_number" : "1234567"}')
file = File.open("sagan.jpg", "rb")
contents = file.read
cert64 = Base64.encode64(contents)
id = '1e29234ee0c84921adec08fbe5980162'
payload = { "id" => id,
            "certificate_base64" => cert64 }
payload = { "id" => id, "certificate_base64" => 'aW4gd2hpY2ggd2UgZmxvYXQsIGxpa2UgYSBtb2F0IG9mIGR1c3QgaW4gdGhl\nIG1vcm5pbmcgc2t5\n'}
method = "put"
type = "json"

a = Rest.new(url, user, pass, type, payload, method)
a.request
