import sys, os, json, argparse
class PreviewReportJsonParser(object):
    def read_from_file(self, file_name):
        try:
            return json.load(open(file_name, 'r'))
        except IOError, e:
            print ("Error: " + str(e))

    def write_to_file(self, file_name, array):
        try:
            with open(file_name, 'w+') as f:
                for item in array:
                    f.write(item + os.linesep)

        except IOError, e:
            print ("ERROR: " + str(e))

    def get_issue_information(self, data):
        return data['issueInfo']
    def count_issues(self, issue_list):
        number_of_cids = len(issue_list)
        return number_of_cids
    def check_new_defects(self, issue_list):
        print ("Checking defects...")
        new_issues = []
        if not issue_list:
            print ("json file is empty or does not exist, force commit")
        for issue in issue_list:
            if issue.get('presentInComparisonSnapshot') == False:
                print ("Found new defect. CID: " + str(issue.get('cid')))
                new_issues.append(str(issue.get('cid')))

        if len(new_issues) == 0:
            print ("No new defects found")

        return new_issues

    def parse_issues(self, input_file_name, output_file_name):
        try:
            data = self.read_from_file(input_file_name)
            issue_list = self.get_issue_information(data)
            print ("Total Number of issues: " + str(self.count_issues(issue_list)))
            new_issues = self.check_new_defects(issue_list)
            if output_file_name:
                self.write_to_file(output_file_name, new_issues)

        except IOError, e:
            print ("ERROR: " + str(e))
        except ValueError, e:
            print ("ERROR: " + str(e))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
    description='Coverity commit preview json parser' + os.linesep)

    parser.add_argument(                  dest="input",  type=str, default=None, help="Input json file")
    parser.add_argument("-o", "--output", dest="output", type=str, default=None, help="File to write new CIDs")

    args = parser.parse_args()
    parser = PreviewReportJsonParser()
    parser.parse_issues(args.input, args.output)

