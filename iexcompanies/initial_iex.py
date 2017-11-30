import sys
from time import mktime
from pymongo import MongoClient
import urllib2
import json
import datetime
import os


from flask import Flask
from flask import render_template


## Check if we need to import data to run
if os.environ.has_key('COSMOSDB'):
    uri = os.environ['COSMOSDB']
else:
    print("Please set the COSMOSDB environment variable!")
    exit()
    
client = MongoClient(uri)

db = client.terraformonazure

companiesdb = db.companies

if (companiesdb.find().count() == 0):

    response = urllib2.urlopen('https://api.iextrading.com/1.0/tops?symbols=FB,MSFT,NFLX,AAPL,GOOGL')
    data = json.load(response)

    for company in data:
        companiesdb.insert_one(company)
        print("Inserting " + company['symbol'])


app = Flask(__name__)

@app.route('/')
def companies_json():
    companies = []
    all_companies = companiesdb.find()
    for company in all_companies:
        print(company)
        companies.append(company)
    

    return render_template('index.html', companies=companies)



