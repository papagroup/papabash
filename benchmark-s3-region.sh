#!/bin/bash

curltime --location --request POST 'http://117.2.155.228:8029/graphql/' \
--header 'Authorization: JWT eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6InVzZXJfYkBjdXJla2Euc2l0ZSIsImV4cCI6MTYwMTU0Mzg3Miwib3JpZ0lhdCI6MTYwMTU0MzU3Mn0.-xfIAC-vCwEEmTDr82s_9h7Vbt0hUa1C8rGz70oZHc8' \
--form 'operations={"query":"mutation( $file1: Upload! ) { postCreate( input: { brand:\"QnJhbmQ6MQ==\" condition:\"Q29uZGl0aW9uOjQ=\" itemName:\"Ao khoac\" size:\"U2l6ZToz\" style:\"U3R5bGU6MQ==\" usedUnder:\"UGVyaW9kOjI=\" caption: \"caption 1\" isPublic: true amount: 10 media: [ { file: $file1 } ] } ) { postErrors { ...PostError } post { ...PostOutput } } } fragment PostOutput on Post { id caption price { amount currency } media { file { url } mimeType } } fragment PostError on PostError { field message code }  ","variables":{"file1":null}}' \
--form 'map={"file1":["variables.file1"]}' \
--form 'file1=@/Users/pii/Downloads/fury10k.png'